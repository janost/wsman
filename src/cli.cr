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
      sub "generate" do
        desc "Generate site configurations."
        usage "new [options] <domain>"
        run do |opts, args|
          log = Logger.new(STDOUT)
          handler = Wsman::Handler.new
          handler.prepare_env
          log.info("Found sites: " + handler.site_manager.names.join(", "))
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
    end
  end
end

Wsman::Cli.start(ARGV)
