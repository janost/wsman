require "file_utils"

module Wsman
  module External
    class Nginx
      def initialize(@config : Wsman::ConfigManager)
      end

      def site_config_exists?(site_name)
        File.exists?(site_config_path(site_name))
      end

      def deploy_site_config(site_name, config)
        File.write(site_config_path(site_name), config)
      end

      def deploy_includes
        Dir["#{@config.fixtures_dir}/nginx-includes/*"].each do |f|
          FileUtils.cp(f, include_path)
        end
      end

      def site_config_path(site_name)
        sites_config_path = File.join(@config.nginx_conf_dir, "conf.d")
        File.join(sites_config_path, "wsman-#{site_name}.conf")
      end

      def include_path
        result = File.join(@config.nginx_conf_dir, "includes")
        Dir.mkdir_p(result)
        result
      end

      def delete_site_config(site_name)
        Wsman::Util.remove_file(site_config_path(site_name))
      end
    end
  end
end
