module Wsman
  module External
    class Awslogs
      def initialize(@config : Wsman::ConfigManager)
      end

      def site_config_exists?(site_name)
        File.exists(site_config_path(site_name))
      end

      def deploy_site_config(site_name, config)
        File.write(site_config_path(site_name), config)
      end

      def site_config_path(site_name)
        Dir.mkdir_p(@config.awslogs_config_path)
        File.join(@config.awslogs_config_path, "wsman-#{site_name}.conf")
      end

      def delete_site_config(site_name)
        Wsman::Util.remove_file(site_config_path(site_name))
      end
    end
  end
end
