require "clim"
require "./handler"
require "./util"

module Wsman
  class Cli < Clim
    main do
      desc "Wsman - manage sites hosted with nginx and php-fpm."
      usage "hello [options] [arguments] ..."
      version "Version 0.1.0"
      run do |opts, args|
        puts opts.help_string
      end
      sub "setup_all" do
        desc "Generate site configurations."
        usage "setup_all"
        run do |opts, args|
          log = Logger.new(STDOUT)
          handler = Wsman::Handler.new
          handler.prepare_env
          log.info("Processing sites: " + handler.site_manager.names.join(", "))
          sites = handler.site_manager.sites
          if sites.size == 0
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
        desc "Generate site configurations."
        usage "setup [options] <sitename>"
        run do |opts, args|
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
  end
end

Wsman::Cli.start(ARGV)
