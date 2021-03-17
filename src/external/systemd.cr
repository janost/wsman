require "file_utils"

module Wsman
  module External
    class Systemd
      def initialize(@config : Wsman::ConfigManager)
      end

      def nginx_restart
        status, _ = Wsman::Util.cmd("/bin/systemctl", ["restart", "nginx"])
        status == 0
      end

      def nginx_reload
        status, _ = Wsman::Util.cmd("/bin/systemctl", ["reload", "nginx"])
        status == 0
      end

      def awslogs_restart
        status, _ = Wsman::Util.cmd("/bin/systemctl", ["restart", "awslogs"])
        status == 0
      end

      def site_running?(site_name)
        status, _ = Wsman::Util.cmd("/bin/systemctl", ["status", "#{@config.template_service_name}@#{site_name}"])
        status == 0
      end

      def site_enable(site_name)
        status, _ = Wsman::Util.cmd("/bin/systemctl", ["enable", "#{@config.template_service_name}@#{site_name}"])
        status == 0
      end

      def site_disable(site_name)
        status, _ = Wsman::Util.cmd("/bin/systemctl", ["disable", "#{@config.template_service_name}@#{site_name}"])
        status == 0
      end

      def site_disable_now(site_name)
        status, _ = Wsman::Util.cmd("/bin/systemctl", ["disable", "#{@config.template_service_name}@#{site_name}", "--now"])
        status == 0
      end

      def site_start(site_name)
        status, _ = Wsman::Util.cmd("/bin/systemctl", ["start", "#{@config.template_service_name}@#{site_name}"])
        status == 0
      end

      def site_stop(site_name)
        status, _ = Wsman::Util.cmd("/bin/systemctl", ["stop", "#{@config.template_service_name}@#{site_name}"])
        status == 0
      end

      def site_restart(site_name)
        status, _ = Wsman::Util.cmd("/bin/systemctl", ["restart", "#{@config.template_service_name}@#{site_name}"])
        status == 0
      end

      def deploy_service(unit_file)
        FileUtils.cp(unit_file, @config.systemd_service_dir)
      end

      def daemon_reload
        status, _ = Wsman::Util.cmd("/bin/systemctl", ["daemon-reload"])
        status == 0
      end

      def solr_instance_start(solr_version_name)
        status, _ = Wsman::Util.cmd("/bin/systemctl", ["start", "solr@#{solr_version_name}"])
        status == 0
      end

      def solr_instance_restart(solr_version_name)
        status, _ = Wsman::Util.cmd("/bin/systemctl", ["restart", "solr@#{solr_version_name}"])
        status == 0
      end

      def solr_instance_stop(solr_version_name)
        status, _ = Wsman::Util.cmd("/bin/systemctl", ["stop", "solr@#{solr_version_name}"])
        status == 0
      end

      def solr_instance_enable(solr_version_name)
        status, _ = Wsman::Util.cmd("/bin/systemctl", ["enable", "solr@#{solr_version_name}"])
        status == 0
      end

      def solr_instance_disable(solr_version_name)
        status, _ = Wsman::Util.cmd("/bin/systemctl", ["disable", "solr@#{solr_version_name}", "--now"])
        status == 0
      end
    end
  end
end
