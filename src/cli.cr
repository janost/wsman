require "clim"
require "log"
require "./handler"
require "./util"

module Wsman
  class Cli < Clim
    main do
      desc "Wsman - manage hosted sites."
      usage "wsman [tool] [command] [arguments] ..."
      version "Version 0.2.0"
      run do |opts, _args|
        puts opts.help_string
      end
      sub "site" do
        desc "Site operations."
        usage "wsman site [command] [arguments]"
        run do |_opts, _args|
          puts "Site operations."
        end
        sub "setup_all" do
          desc "Generate site configurations."
          usage "setup_all"
          run do |_opts, _args|
            handler = Wsman::Handler.new
            handler.prepare_env
            Log.info { "Processing sites: " + handler.site_manager.names.join(", ") }
            sites = handler.site_manager.sites
            if sites.empty?
              Log.info { "No sites found. Exiting..." }
              exit 0
            end
            sites.each do |site|
              handler.process_site(site)
            end
            handler.post_process
          end
        end

        sub "setup" do
          desc "Generate site configurations for the given site."
          usage "setup [options] <sitename>"
          option "--skip-solr", type: Bool, desc: "Skip Solr core install, even if it's configured.", default: false
          argument "site-name", desc: "Site name to process", type: String, required: true
          run do |opts, args|
            handler = Wsman::Handler.new
            handler.prepare_env
            handler.site_manager.sites.each do |site|
              if args.site_name == site.site_name
                site.skip_solr = opts.skip_solr
                handler.process_site(site)
              end
            end
            handler.post_process
          end
        end

        sub "setup_solr" do
          desc "Generate solr configurations for the given site."
          usage "setup_solr <sitename>"
          argument "site-name", desc: "Site name to process", type: String, required: true
          run do |_opts, args|
            handler = Wsman::Handler.new
            handler.site_manager.sites.each do |site|
              if args.site_name == site.site_name
                handler.setup_solr(site)
              end
            end
          end
        end
      end

      sub "ci" do
        desc "CI operations."
        usage "wsman ci [command] [arguments]"
        run do |_opts, _args|
          puts "CI operations."
        end
        sub "zipinstall" do
          desc "Installs a zipped site artifact to the webroot."
          usage "zipinstall --site <sitename> --zip <zip-path>"
          option "-f", "--force", type: Bool, desc: "Overwrite target directory.", default: false
          option "-s SITE", "--site=SITE", type: String, required: true, desc: "Main hostname of the site. This is also used as the directory name."
          option "-z ZIP", "--zip ZIP", type: String, required: true, desc: "Path to the archive."
          run do |opts, _args|
            handler = Wsman::Handler.new
            unless File.exists?(opts.zip)
              Log.error { "Provided archive #{opts.zip} doesn't exist, aborting." }
              exit 1
            end
            if handler.site_manager.site_exists?(opts.site)
              if opts.force
                Log.info { "Site #{opts.site} already exists, forcing install on user request..." }
              else
                Log.error { "Site #{opts.site} already exists, aborting." }
                exit 1
              end
            else
              Log.info { "Site #{opts.site} doesn't exist yet, moving on..." }
            end
            Log.info { "Installing artifact #{opts.zip} as #{opts.site}..." }
            handler.site_manager.create_site_root(opts.site)
            site_root = handler.site_manager.site_root(opts.site)
            site_docroot = handler.site_manager.site_docroot(opts.site)
            status,output = Wsman::Util.cmd("unzip", ["-o", opts.zip, "-d", site_root])
            if status == 0
              gid = Wsman::Util.get_gid_for("web")
              uid = Wsman::Util.get_uid_for("web")
              Dir["#{site_root}/**/*"].each do |path|
                File.chown(path, uid: uid, gid: gid)
              end
              Dir["#{site_docroot}/**/*"].each do |path|
                if File.file?(path)
                  File.chmod(path, 0o644)
                else
                  File.chmod(path, 0o755)
                end
              end
              Log.info { "  Installation successful." }
            else
              Log.error { "  Installation failed." }
            end
          end
        end
        sub "cleanup" do
          desc "Cleans up a site from the server."
          usage "cleanup --site <sitename>"
          option "-s SITE", "--site=SITE", type: String, required: true, desc: "Main hostname of the site. This is also used as the directory name."
          run do |opts, _args|
            handler = Wsman::Handler.new
            handler.cleanup(opts.site)
          end
        end
        sub "cleanup_solr" do
          desc "Cleans up a site's solr"
          usage "cleanup_solr --site <sitename>"
          option "-s SITE", "--site=SITE", type: String, required: true, desc: "Main hostname of the site. This is also used as the directory name."
          run do |opts, _args|
            handler = Wsman::Handler.new
            handler.cleanup_solr(opts.site)
          end
        end

        sub "list_sites" do
          desc "List the stored sites."
          usage "list_sites"
          run do |_opts, _args|
            handler = Wsman::Handler.new
            puts handler.list_sites
          end
        end
      end
    end
  end
end

Wsman::Cli.start(ARGV)
