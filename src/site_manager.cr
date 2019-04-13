require "./model/site"

module Wsman
  class SiteManager
    def initialize(@config : Wsman::ConfigManager)
      @sites = Array(Wsman::Model::Site).new
    end

    def names
      Dir.children(@config.web_root_dir)
    end

    def site_exists?(site_name)
      Dir.exists?(File.join(@config.web_root_dir, site_name))
    end

    def sites
      @sites.clear
      names.each do |site_name|
        @sites << Wsman::Model::Site.new(@config, site_name)
      end
      @sites
    end
  end
end
