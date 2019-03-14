require "file_utils"

module Wsman
  module External
    class Systemd
      def initialize(@config : Wsman::ConfigManager)
      end

      def nginx_restart
        %x(systemctl restart nginx)
      end

      def nginx_reload
        %x(systemctl reload nginx)
      end

      def awslogs_restart
        %x(systemctl restart awslogs)
      end

      def site_running?(site_name)
        status, output = run_cmd("/bin/systemctl", ["status", "#{@config.template_service_name}@#{site_name}"])
        status == 0
      end

      def site_enable(site_name)
        %x(systemctl enable #{@config.template_service_name}@#{site_name})
      end

      def site_disable(site_name)
        %x(systemctl disable #{@config.template_service_name}@#{site_name})
      end

      def site_start(site_name)
        %x(systemctl start #{@config.template_service_name}@#{site_name})
      end

      def site_stop(site_name)
        %x(systemctl stop #{@config.template_service_name}@#{site_name})
      end

      def site_restart(site_name)
        %x(systemctl restart #{@config.template_service_name}@#{site_name})
      end

      def deploy_service(unit_file)
        FileUtils.cp(unit_file, @config.systemd_service_dir)
      end

      def daemon_reload
        %x(systemctl daemon-reload)
      end

      private def run_cmd(cmd, args = [] of String)
        stdout = IO::Memory.new
        stderr = IO::Memory.new
        status = Process.run(cmd, args: args, output: stdout, error: stderr)
        if status.success?
          {status.exit_code, stdout.to_s.strip}
        else
          {status.exit_code, stderr.to_s.strip}
        end
      end
    end
  end
end
