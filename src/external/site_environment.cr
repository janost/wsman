module Wsman
  module External
    class SiteEnvironment
      def initialize(@config : Wsman::ConfigManager)
      end

      def deploy_env(site_name, env)
        File.write(env_file(site_name), env)
        File.chmod(env_file(site_name), 0o400)
      end

      def env_file(site_name)
        File.join(
          @config.docker_environment_dir,
          "#{@config.docker_environment_prefix}#{site_name}"
        )
      end
    end
  end
end
  