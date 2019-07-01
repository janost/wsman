require "llvm/lib_llvm"
require "llvm/enums"

require "clim"
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
        run do |opts, args|
          puts "Site operations."
        end
        sub "setup_all" do
          desc "Generate site configurations."
          usage "setup_all"
          run do |_opts, _args|
            log = Logger.new(STDOUT)
            handler = Wsman::Handler.new
            handler.prepare_env
            log.info("Processing sites: " + handler.site_manager.names.join(", "))
            sites = handler.site_manager.sites
            if sites.empty?
              log.info("No sites found. Exiting...")
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
          run do |_opts, args|
            log = Logger.new(STDOUT)
            if args.size == 0
              log.info("Please list sites to process.")
              Process.exit(0)
            end
            handler = Wsman::Handler.new
            handler.prepare_env
            handler.site_manager.sites.each do |site|
              if args.includes? site.site_name
                handler.process_site(site)
              end
            end
            handler.post_process
          end
        end
      end

      sub "ci" do
        desc "CI operations."
        usage "wsman ci [command] [arguments]"
        run do |opts, args|
          puts "CI operations."
        end
        sub "zipinstall" do
          desc "Installs a zipped site artifact to the webroot."
          usage "zipinstall --site <sitename> --zip <zip-path>"
          option "-f", "--force", type: Bool, desc: "Overwrite target directory.", default: false
          option "-s SITE", "--site=SITE", type: String, required: true, desc: "Main hostname of the site. This is also used as the directory name."
          option "-z ZIP", "--zip ZIP", type: String, required: true, desc: "Path to the archive."
          run do |opts, args|
            log = Logger.new(STDOUT)
            handler = Wsman::Handler.new
            unless File.exists?(opts.zip)
              log.error("Provided archive #{opts.zip} doesn't exist, aborting.")
              exit 1
            end
            if handler.site_manager.site_exists?(opts.site)
              if opts.force
                log.info("Site #{opts.site} already exists, forcing install on user request...")
              else
                log.error("Site #{opts.site} already exists, aborting.")
                exit 1
              end
            else
              log.info("Site #{opts.site} doesn't exist yet, moving on...")
            end
            log.info("Installing artifact #{opts.zip} as #{opts.site}...")
            handler.site_manager.create_site_root(opts.site)
            site_root = handler.site_manager.site_root(opts.site)
            status,output = Wsman::Util.cmd("unzip", ["-o", opts.zip, "-d", site_root])
            if status == 0
              gid = Wsman::Util.get_gid_for("web")
              Dir["#{site_root}/**/*"].each do |path|
                File.chown(path, gid: gid)
                if File.directory?(path)
                  File.chmod(path, 0o775)
                end
              end
              log.info("  Installation successful.")
            else
              log.error("  Installation failed.")
            end
          end
        end
        sub "cleanup" do
          desc "Cleans up a site from the server."
          usage "cleanup --site <sitename>"
          option "-s SITE", "--site=SITE", type: String, required: true, desc: "Main hostname of the site. This is also used as the directory name."
          run do |opts, args|
            handler = Wsman::Handler.new
            handler.cleanup(opts.site)
          end
        end

        sub "list_sites" do
          desc "List the stored sites."
          usage "list_sites"
          run do |opts, args|
            handler = Wsman::Handler.new
            puts handler.list_sites
          end
        end
      end
    end
  end
end

Wsman::Cli.start(ARGV)
