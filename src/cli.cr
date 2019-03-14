require "clim"
require "./config"
require "./site_manager"
require "./external/nginx"
require "./external/systemd"
require "./external/awslogs"
require "./external/mysql"
require "./external/site_environment"

module Wsman
  class Cli < Clim
    main do
      desc "Wsman - manage sites hosted with nginx and php-fpm."
      usage "hello [options] [arguments] ..."
      version "Version 0.1.0"
      run do |opts, args|
        puts opts.help_string
      end
      sub "generate" do
        desc "Generate site configurations."
        usage "new [options] <domain>"
        run do |opts, args|
          config = Wsman::ConfigManager.new
          nginx = Wsman::External::Nginx.new(config)
          systemd = Wsman::External::Systemd.new(config)
          awslogs = Wsman::External::Awslogs.new(config)
          mysql = Wsman::External::Mysql.new(config)
          site_env = Wsman::External::SiteEnvironment.new(config)
          log = Logger.new(STDOUT)        
          site_manager = Wsman::SiteManager.new(config)
          log.info("Deploying systemd service: #{config.template_service_name}...")
          systemd.deploy_service(File.join(config.fixtures_dir, "systemd", "#{config.template_service_name}@.service"))
          log.info("Reloading systemd configuration...")
          systemd.daemon_reload
          log.info("Found sites: " + site_manager.names.join(", "))
          sites = site_manager.sites
          if sites.size == 0
            log.info("No sites found. Exiting...")
            exit 0
          end
          sites.each do |site_name, site|
            log.info("[#{site_name}] Validating configuration...")
            log.info("  Looking for certificate and key...")
            if site.has_valid_cert?
              log.info("  Found proper certificate and key. Will set up nginx to use them.")
            else
              log.warn("  Couldn't find valid certificate and key. Please make sure exactly one `.crt` and exactly one `.key` file exists in the `cert` subdirectory for the site. This site WILL NOT USE TLS!")
            end
            if site.needs_php?
              restart_service = site.dcompose_changed?
              if restart_service
                log.info("  Docker-compose file needs updating.")
                log.info("  Writing #{config.docker_compose_filename}...")
                site.save_dcompose
              else
                log.info("  Docker-compose file is up-to-date. No changes necessary.")
              end
              log.info("  Checking DB config...")
              if config.has_db_config?(site_name)
                log.info("  Site already has DB configuration.")
              else
                log.info("  Site doesn't have DB configuration, generating...")
                db_name, db_username, db_password = mysql.generate_creds(site_name)
                config.set_db_config(site_name, db_name, db_username, db_password)
                mysql.setup_db(db_name, db_username, db_password)
                log.info("  Writing site environment to #{site_env.env_file(site_name)}...")
                site_env.deploy_env(site_name, site.render_site_env)
                restart_service = true
              end
              log.info("  Enabling systemd service for the site runtime container...")
              systemd.site_enable(site_name)
              if restart_service
                log.info("  Restarting systemd service for the site runtime container...")
                systemd.site_restart(site_name)
              else
                if systemd.site_running?(site_name)
                  log.info("  The site container is running. We don't need to restart it.")
                else
                  log.info("  The site container is NOT running. Restarting...")
                  systemd.site_restart(site_name)
                end
              end
            else
              log.info("  Site doesn't need a runtime container, stopping/disabling service if necessary...")
              systemd.site_disable(site_name)
              systemd.site_stop(site_name)
            end
            # TODO: do we always need to do these?
            log.info("  Deploying site configuration #{nginx.site_config_path(site_name)}...")
            nginx.deploy_site_config(site_name, site.render_nginx)
            log.info("  Deploying awslogs config #{awslogs.site_config_path(site_name)}...")
            awslogs.deploy_site_config(site_name, site.render_awslogs)
          end
          log.info("Deploying nginx includes...")
          nginx.deploy_includes
          log.info("Reloading nginx...")
          systemd.nginx_reload
          log.info("Restarting awslogs...")
          systemd.awslogs_restart
          log.info("Done!")
        end
      end
    end
  end
end

Wsman::Cli.start(ARGV)
