require "./config"
require "./site_manager"
require "./external/nginx"
require "./external/systemd"
require "./external/awslogs"
require "./external/mysql"

module Wsman
  class Handler
    getter site_manager

    def initialize
      @config = Wsman::ConfigManager.new
      @nginx = Wsman::External::Nginx.new(@config)
      @systemd = Wsman::External::Systemd.new(@config)
      @awslogs = Wsman::External::Awslogs.new(@config)
      @mysql = Wsman::External::Mysql.new(@config)
      @log = Logger.new(STDOUT)
      @site_manager = Wsman::SiteManager.new(@config)
    end

    def prepare_env
      @log.info("Deploying systemd service: #{@config.template_service_name}...")
      @systemd.deploy_service(File.join(@config.fixtures_dir, "systemd", "#{@config.template_service_name}@.service"))
      @log.info("Reloading systemd configuration...")
      @systemd.daemon_reload
      @log.info("Deploying nginx includes...")
      @nginx.deploy_includes
    end

    def post_process
      @log.info("Reloading nginx...")
      @systemd.nginx_reload
      @log.info("Restarting awslogs...")
      @systemd.awslogs_restart
    end

    def process_site(site, extra_envfile=nil)
      site_name = site.site_name
      @log.info("[#{site_name}] Validating configuration...")
      @log.info("  Looking for certificate and key...")
      if site.has_valid_cert?
        @log.info("  Found proper certificate and key. Will set up nginx to use them.")
      else
        @log.warn("  Couldn't find valid certificate and key. Please make sure exactly one `.crt` and exactly one `.key` file exists in the `cert` subdirectory for the site. This site WILL NOT USE TLS!")
      end
      if site.needs_dcompose?
        restart_service = site.dcompose_changed?
        if restart_service
          @log.info("  Docker-compose file needs updating.")
          @log.info("  Writing #{@config.docker_compose_filename}...")
          site.save_dcompose
        else
          @log.info("  Docker-compose file is up-to-date. No changes necessary.")
        end
        @log.info("  Applying DB config...")
        site.siteconf.databases.each do |db|
          if @config.has_db?(site_name, db)
            @log.info("    #{db} already exists.")
          else
            @log.info("    #{db} doesn't exist, creating...")
            db_name = @mysql.generate_name(site_name, db)
            user = @mysql.generate_user(site_name)
            @log.info("    Creating database #{db_name} with user #{user}")
            db_password = Wsman::Util.randstr(32)
            @mysql.setup_db(db_name, user, db_password)
            @log.info("    #{db} created as #{db_name}")
            if @config.add_db_config(site_name, db, db_name, user, db_password)
              @log.info("    #{db} configuration has been saved.")
            else
              @log.error("    Error saving configuration for #{db}!")
            end
          end
        end
        if extra_envfile
          extra_envs = File.read(extra_envfile)
          new_env = site.render_site_env + "\n" + extra_envs
        else
          new_env = site.render_site_env
        end
        if @config.env_changed?(site_name, new_env)
          @log.info("  Writing site environment to #{site.env_file}...")
          @config.deploy_env(site_name, new_env)
          @log.info("  Adding #{site.env_file} to #{@config.docker_compose_filename}...")
          site.save_dcompose
          restart_service = true
        end
        @log.info("  Enabling systemd service for the site runtime container...")
        if @systemd.site_enable(site_name)
          @log.info("  The site container has been enabled.")
        else
          @log.error("  Error enabling site container!")
        end
        if restart_service
          @log.info("  Restarting systemd service for the site runtime container...")
          if @systemd.site_restart(site_name)
            @log.info("  The site container has been restarted.")
          else
            @log.error("  Error restarting site container!")
          end
        else
          if @systemd.site_running?(site_name)
            @log.info("  The site container is running. We don't need to restart it.")
          else
            @log.info("  The site container is NOT running. Restarting...")
            if @systemd.site_restart(site_name)
              @log.info("  The site container has been restarted.")
            else
              @log.error("  Error restarting site container!")
            end
          end
        end
      else
        @log.info("  Site doesn't need a runtime container, stopping/disabling service if necessary...")
        @systemd.site_disable(site_name)
        @systemd.site_stop(site_name)
      end
      # TODO: do we always need to do these?
      @log.info("  Deploying site configuration #{@nginx.site_config_path(site_name)}...")
      @nginx.deploy_site_config(site_name, site.render_nginx)
      @log.info("  Deploying awslogs config #{@awslogs.site_config_path(site_name)}...")
      @awslogs.deploy_site_config(site_name, site.render_awslogs)
    end

    def cleanup(site_name)
      @log.info("Cleaning up #{site_name}.")
      @systemd.site_disable_now(site_name)
      databases = @config.get_db_config(site_name)
      @mysql.delete_databases(databases)
      @site_manager.delete_site_root(site_name)
      @nginx.delete_site_config(site_name)
      @awslogs.delete_site_config(site_name)
      @config.delete_site_config(site_name)
      @log.info("Successfully cleaned up #{site_name}.")
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