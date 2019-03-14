require "./model/site"

module Wsman
  class SiteManager
    def initialize(@config : Wsman::ConfigManager)
      @sites = Hash(String, Wsman::Model::Site).new
    end

    def names
      Dir.entries(@config.web_root_dir).reject(/^\.|\.\.$/)
    end

    def sites
      names.each do |site_name|
        @sites[site_name] = Wsman::Model::Site.new(@config, site_name)
      end
      @sites
    end
  end
end
