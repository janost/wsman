require "./model/site"

module Wsman
  class SiteManager
    def initialize(@config : Wsman::ConfigManager)
      @sites = Array(Wsman::Model::Site).new
    end

    def names
      Dir.children(@config.web_root_dir).reject { |x| !Dir.exists?(x) }
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
