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

      def drop_db(db_name)
        mysql_query("DROP DATABASE #{db_name};")
      end

      def drop_user(username)
        mysql_query("DROP USER '#{username}'@'%';");
      end

      def delete_databases(databases)
        databases.each do |db|
          drop_db(db.dbname)
          drop_user(db.username)
        end
      end

      def generate_name(site_name, confname)
        dbname = "#{confname}_#{site_name.gsub('-', '_').split(".").first}"
        dbname = dbname[0, 23] if dbname.size > 23
        "#{dbname}_#{Wsman::Util.randstr(10)}"
      end

      def generate_user(site_name)
        user = site_name.gsub('-', '_').split(".").first
        user = user[0, 19]
        "#{user}_#{Wsman::Util.randstr(10)}"
      end

      private def mysql_query(query)
        %x(MYSQL_PWD=$(#{@config.mysql_pwd_cmd}) mysql -e \"#{query}\")
      end

      private def mysql_admin_pass
        cmd = @config.mysql_pwd_cmd
        status, output = Wsman::Util.cmd(cmd)
        if (status == 0)
          output
        else
          raise "Failed to get mysql pass from #{@config.mysql_pwd_cmd}..."
        end
      end
    end
  end
end
