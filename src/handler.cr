require "./config"
require "./site_manager"
require "./external/nginx"
require "./external/systemd"
require "./external/awslogs"
require "./external/mysql"
require "crinja"
require "log"

module Wsman
  class Handler
    getter site_manager

    def initialize
      @config = Wsman::ConfigManager.new
      @nginx = Wsman::External::Nginx.new(@config)
      @systemd = Wsman::External::Systemd.new(@config)
      @awslogs = Wsman::External::Awslogs.new(@config)
      @mysql = Wsman::External::Mysql.new(@config)
      @site_manager = Wsman::SiteManager.new(@config)
    end

    private def crinja_template(template_name)
      env = Crinja.new
      env.loader = Crinja::Loader::FileSystemLoader.new(File.join(@config.fixtures_dir, "templates"))
      env.get_template(template_name)
    end

    def prepare_env
      Log.info { "Deploying systemd services: #{@config.template_service_name}..." }
      @systemd.deploy_service(File.join(@config.fixtures_dir, "systemd", "#{@config.template_service_name}@.service"))
      File.write("/tmp/solr@.service", crinja_template("solr@.service.j2").render({"solr_data_path" => @config.solr_data_path}))
      @systemd.deploy_service("/tmp/solr@.service")
      Log.info { "Reloading systemd configuration..." }
      @systemd.daemon_reload
      Log.info { "Deploying nginx includes..." }
      @nginx.deploy_includes
    end

    def post_process
      Log.info { "Reloading nginx..." }
      @systemd.nginx_reload
      Log.info { "Restarting awslogs..." }
      @systemd.awslogs_restart
    end

    def process_site(site)
      site_name = site.site_name
      Log.info { "[#{site_name}] Validating configuration..." }
      Log.info { "  Looking for certificate and key..." }
      if site.has_valid_cert?
        Log.info { "  Found proper certificate and key. Will set up nginx to use them." }
      else
        Log.warn { "  Couldn't find valid certificate and key. Please make sure exactly one `.crt` and exactly one `.key` file exists in the `cert` subdirectory for the site. This site WILL NOT USE TLS!" }
      end
      if site.needs_dcompose?
        restart_service = site.dcompose_changed?
        if restart_service
          Log.info { "  Docker-compose file needs updating." }
          Log.info { "  Writing #{@config.docker_compose_filename}..." }
          site.save_dcompose
        else
          Log.info { "  Docker-compose file is up-to-date. No changes necessary." }
        end
        Log.info { "  Applying DB config..." }
        site.siteconf.databases.each do |db|
          if @config.has_db?(site_name, db)
            Log.info { "    #{db} already exists." }
          else
            Log.info { "    #{db} doesn't exist, creating..." }
            db_name = @mysql.generate_name(site_name, db)
            user = @mysql.generate_user(site_name)
            Log.info { "    Creating database #{db_name} with user #{user}" }
            db_password = Wsman::Util.randstr(32)
            @mysql.setup_db(db_name, user, db_password)
            Log.info { "    #{db} created as #{db_name}" }
            if @config.add_db_config(site_name, db, db_name, user, db_password)
              Log.info { "    #{db} configuration has been saved." }
            else
              Log.error { "    Error saving configuration for #{db}!" }
            end
          end
        end
        setup_solr(site)
        restart_service = setup_env(site)
        Log.info { "  Enabling systemd service for the site runtime container..." }
        if @systemd.site_enable(site_name)
          Log.info { "  The site container has been enabled." }
        else
          Log.error { "  Error enabling site container!" }
        end
        if restart_service
          Log.info { "  Restarting systemd service for the site runtime container..." }
          if @systemd.site_restart(site_name)
            Log.info { "  The site container has been restarted." }
          else
            Log.error { "  Error restarting site container!" }
          end
        else
          if @systemd.site_running?(site_name)
            Log.info { "  The site container is running. We don't need to restart it." }
          else
            Log.info { "  The site container is NOT running. Restarting..." }
            if @systemd.site_restart(site_name)
              Log.info { "  The site container has been restarted." }
            else
              Log.error { "  Error restarting site container!" }
            end
          end
        end
      else
        Log.info { "  Site doesn't need a runtime container, stopping/disabling service if necessary..." }
        @systemd.site_disable(site_name)
        @systemd.site_stop(site_name)
      end
      # TODO: do we always need to do these?
      Log.info { "  Deploying site configuration #{@nginx.site_config_path(site_name)}..." }
      @nginx.deploy_site_config(site_name, site.render_nginx)
      Log.info { "  Deploying awslogs config #{@awslogs.site_config_path(site_name)}..." }
      @awslogs.deploy_site_config(site_name, site.render_awslogs)
    end

    def setup_env(site)
      new_env = site.render_site_env
      restart_service = false
      if @config.env_changed?(site.site_name, new_env)
        Log.info { "  Writing site environment to #{site.env_file}..." }
        @config.deploy_env(site.site_name, new_env)
        Log.info { "  Adding #{site.env_file} to #{@config.docker_compose_filename}..." }
        site.save_dcompose
        restart_service = true
      end
      restart_service
    end

    def setup_solr(site)
      site_name = site.site_name
      if !site.skip_solr
        solr_cores = site.siteconf.solr_cores
        if !solr_cores.empty?
          Log.info { "  Check Solr config..." }
          solr_version = site.siteconf.solr_version
          if solr_version.nil?
              Log.error { "    The solrCores added in the site.yml, but the solrVersion is missing!" }
          else
            if @config.has_solr_container?(solr_version)
              Log.info { "    The Solr container with version '#{solr_version}' already exists." }
            else
              Log.info { "    The Solr container with version '#{solr_version}' doesn't exist, creating..." }
            end
            @config.create_or_update_solr_container(solr_version, site.render_solr_dcompose)
            if @systemd.solr_instance_enable(@config.solr_version_name(solr_version))
              Log.info { "    The Solr instance container has been enabled." }
            else
              Log.error { "    Error when enabling Solr instance container!" }
            end
            if @systemd.solr_instance_start(@config.solr_version_name(solr_version))
              Log.info { "    The Solr instance container has been started." }
            else
              Log.error { "    Error when starting Solr instance container!" }
            end
            db_solr_cores = @config.get_solr_cores_from_db(site_name)
            solr_cores.each do |confname|
              solr_core_config_dir = site.solr_core_config_dir(confname)
              if !solr_core_config_dir.nil?
                solr_corename = @config.generate_solr_corename(confname, site_name)
                if @config.solr_core_exists?(db_solr_cores, solr_corename)
                  @config.update_solr_core_site_id(site_name, solr_corename)
                  Log.info { "    #{confname} core already exists on db, site id updated" }
                else
                  Log.info { "    #{confname} core not exists on db, now creating" }
                  solr_corename = @config.add_solr_config_to_db(confname, site_name, solr_version)
                end
                if !solr_corename.nil?
                  Log.info { "    #{confname} configuration has been saved." }
                  @config.create_solr_core(solr_version, solr_corename, solr_core_config_dir)
                  if @systemd.solr_instance_restart(@config.solr_version_name(solr_version))
                    Log.info { "    The Solr instance container has been restarted." }
                  else
                    Log.error {"    Error when restart Solr instance container!" }
                  end
                else
                  Log.error { "    Error saving configuration for #{confname}!" }
                end
              else
                Log.error { "    The Solr config #{confname}'s directory not found!" }
              end
            end
          end
        else
          Log.info { "  The site not uses Solr." }
        end
      else
        Log.info { "  Solr core install skipped." }
      end
      restart_site_service = setup_env(site)
      if restart_site_service
        Log.info { "  Solr config changed, restarting systemd service for the site runtime container..." }
        if @systemd.site_restart(site_name)
          Log.info { "  The site container has been restarted." }
        else
          Log.error { "  Error restarting site container!" }
        end
      end
    end

    def cleanup(site_name)
      Log.info { "Cleaning up #{site_name}." }
      cleanup_solr(site_name)
      @systemd.site_disable_now(site_name)
      databases = @config.get_db_config(site_name)
      @mysql.delete_databases(databases)
      @site_manager.delete_site_root(site_name)
      @nginx.delete_site_config(site_name)
      @awslogs.delete_site_config(site_name)
      @config.delete_site_config(site_name)
      Log.info { "Successfully cleaned up #{site_name}." }
    end

    def cleanup_solr(site_name)
      solr_cores = @config.get_solr_cores_from_db(site_name)
      if !solr_cores.empty?
        Log.info { "Start to remove Solr cores..." }
        solr_version = solr_cores.first.solr_version
        solr_version_name = @config.solr_version_name(solr_version)
        @config.delete_solr_cores(solr_cores)
        Log.info { "Solr core(s) removed from solr instance" }
        if @systemd.solr_instance_restart(solr_version_name)
          Log.info { "The solr instance container has been restarted." }
        else
          Log.error { "Error when enabling solr instance container!" }
        end
        @config.remove_solr_cores_from_db(site_name)
        Log.info { "Solr core(s) removed from database" }
        if ! @config.solr_instance_has_cores?(solr_cores.first.solr_instance_id)
          @systemd.solr_instance_disable(solr_version_name)
          @config.remove_solr_instance_from_db(solr_version)
          Log.info { "Solr instance removed from db" }
          @config.delete_solr_instance(solr_version)
          Log.info { "Solr instance removed" }
        end
      end
    end

    def list_sites
      DB.open "sqlite3://#{@config.db_path}" do |db|
        db.query "SELECT * FROM sites" do |rs|
          rs.column_names.each do |c|
            print "|#{c}"
          end
          puts
          rs.each do
            name = rs.read(String)
            id = rs.read(Int32)
            puts "#{name} #{id}"
          end
        end
      end
    end
  end
end
