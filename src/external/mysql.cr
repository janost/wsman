module Wsman
  module External
    class Mysql
      def initialize(@config : Wsman::ConfigManager)
      end

      def setup_db(db_name, db_username, db_password)
        mysql_query("CREATE DATABASE IF NOT EXISTS #{db_name};")
        mysql_query("CREATE USER IF NOT EXISTS '#{db_username}'@'%' IDENTIFIED BY '#{db_password}';")
        mysql_query("GRANT ALL ON #{db_name}.* TO '#{db_username}'@'%';")
      end

      def generate_creds(site_name)
        db_username = site_name.gsub(/[^a-zA-Z]/, "")
        db_username = db_username[0, 32] if db_username.size > 32
        db_name = db_username
        db_password = Random::Secure.base64(16)
        {db_name, db_username, db_password}
      end

      private def mysql_query(query)
        %x(MYSQL_PWD=$(#{@config.mysql_pwd_cmd}) mysql -e \"#{query}\")
      end

      private def mysql_admin_pass
        cmd = @config.mysql_pwd_cmd
        status, output = run_cmd(cmd)
        if (status == 0)
          output
        else
          raise "Failed to get mysql pass from #{@config.mysql_pwd_cmd}..."
        end
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
