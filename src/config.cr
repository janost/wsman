require "yaml"
require "sqlite3"

require "./model/db_config"

module Wsman
  class Config
    YAML.mapping(
      nginx_conf_dir: {
        type:    String,
        default: "/etc/nginx",
      },
      fixtures_dir: {
        type:    String,
        default: "#{ENV["HOME"]}/.config/wsman/fixtures",
      },
      web_root_dir: {
        type:    String,
        default: "/srv/www",
      },
      docker_compose_filename: {
        type:    String,
        default: "docker-compose.yml",
      },
      container_image: {
        type:    String,
        default: "webdevops/php:alpine-php7",
      },
      container_htdocs: {
        type:    String,
        default: "/htdocs",
      },
      container_subnet: {
        type:    String,
        default: "172.28.200.",
      },
      container_network: {
        type:    String,
        default: "web",
      },
      web_user: {
        type:    String,
        default: "web",
      },
      web_group: {
        type:    String,
        default: "web",
      },
      phpfpm_port: {
        type:    Int32,
        default: 9000,
      },
      template_service_name: {
        type:    String,
        default: "wsd",
      },
      awslogs_prefix: {
        type:    String,
        default: "simple-webhost",
      },
      awslogs_config_path: {
        type:    String,
        default: "/var/awslogs/etc/config",
      },
      mysql_pwd_cmd: {
        type:    String,
        default: "/opt/get-db-password.sh",
      },
      systemd_service_dir: {
        type:    String,
        default: "/etc/systemd/system",
      },
      docker_environment_dir: {
        type:    String,
        default: "/etc/wsman-sites",
      },
      docker_environment_prefix: {
        type:    String,
        default: "wsd-",
      },
      hosting_env_file: {
        type:    String,
        default: "/etc/wsman-sites/hosting-env",
      },
      stack_name_cmd: {
        type:    String,
        default: "/opt/stack-name.sh",
      },
    )

    def initialize(config_base)
      @nginx_conf_dir = "/etc/nginx"
      @fixtures_dir = File.join(config_base, "fixtures")
      @web_root_dir = "/srv/www"
      # Currently we're limited to a /16 subnet
      @container_subnet = "172.28."
      @container_network = "web"
      @container_image = "webdevops/php:alpine-php7"
      @container_htdocs = "/htdocs"
      @docker_compose_filename = "docker-compose.yml"
      @web_user = "web"
      @web_group = "web"
      @phpfpm_port = 9000
      @template_service_name = "wsd"
      @awslogs_prefix = "simple-webhost"
      @awslogs_config_path = "/var/awslogs/etc/config"
      @mysql_pwd_cmd = "/opt/get-db-password.sh"
      @systemd_service_dir = "/etc/systemd/system"
      @docker_environment_dir = "/etc/wsman-sites"
      @docker_environment_prefix = "wsd-"
      @hosting_env_file = "/etc/wsman-sites/hosting-env"
      @stack_name_cmd = "/opt/stack-name.sh"
    end
  end

  class ConfigManager
    getter wsman_version

    def initialize
      config_base = File.dirname(Process.executable_path || ".") || "#{ENV["HOME"]}/.config/wsman"
      config_dir = File.join(config_base, "config")
      Dir.mkdir_p(config_dir) unless Dir.exists?(config_dir)
      @config_path = File.join(config_dir, "config.yml")
      if File.exists?(@config_path)
        @config = Config.from_yaml(File.read(@config_path))
      else
        @config = Config.new(config_base)
        save
      end
      @db_path = File.join(config_dir, "config.db")
      unless File.exists?(@db_path)
        init_db
      end
      @wsman_version = "0.1"
    end

    def nginx_conf_dir
      @config.nginx_conf_dir
    end

    def fixtures_dir
      @config.fixtures_dir
    end

    def web_root_dir
      result = @config.web_root_dir
      Dir.mkdir_p(result)
      result
    end

    def container_ip(site_name)
      ip_id = nil
      ip = nil
      DB.open "sqlite3://#{@db_path}" do |db|
        db.query "SELECT ip_id FROM sites WHERE name = ?", site_name do |rs|
          rs.each do
            ip_id = rs.read(Int32)
          end
        end
        if ip_id.nil?
          db.query "SELECT rowid, ip FROM ips WHERE rowid NOT IN (SELECT ip_id FROM sites) ORDER BY rowid LIMIT 1" do |rs|
            rs.each do
              ip_id = rs.read(Int32)
              ip = rs.read(String)
            end
          end
          db.exec "INSERT OR IGNORE INTO sites (name) VALUES (?)", site_name
          db.exec "UPDATE sites SET ip_id = ? WHERE name = ?", ip_id, site_name
        else
          db.query "SELECT ip FROM ips WHERE rowid = ?", ip_id do |rs|
            rs.each do
              ip = rs.read(String)
            end
          end
        end
      end
      ip
    end

    def has_db?(site_name, confname)
      confname = confname.upcase
      databases = get_db_config(site_name)
      db_confnames = databases.map { |x| x.confname }
      db_confnames.includes? confname
    end

    def add_db_config(site_name, confname, dbname, username, password)
      confname = confname.upcase
      return false if has_db?(site_name, confname)

      DB.open "sqlite3://#{@db_path}" do |db|
        db.exec "INSERT OR IGNORE INTO sites (name) VALUES (?)", site_name
        site_id = db_site_id(db, site_name)

        db.exec "INSERT OR IGNORE INTO dbs (site_id, confname, dbname, username, password) "\
                "VALUES (?, ?, ?, ?, ?)",
                site_id, confname, dbname, username, password
      end
      true
    end

    def get_db_config(site_name)
      databases = Array(Wsman::Model::DbConfig).new
      DB.open "sqlite3://#{@db_path}" do |db|
        site_id = db_site_id(db, site_name)
        return databases unless site_id
        
        db.query "SELECT confname, dbname, username, password FROM dbs WHERE site_id = ?", site_id do |rs|
          rs.each do
            confname = rs.read(String)
            dbname = rs.read(String)
            username = rs.read(String)
            password = rs.read(String)
            databases << Wsman::Model::DbConfig.new(confname, dbname, username, password)
          end
        end
      end
      databases
    end

    def db_site_id(db, site_name)
      site_id = nil
      db.query "SELECT rowid FROM sites WHERE name = ?", site_name do |rs|
        rs.each do
          site_id = rs.read(Int32)
        end
      end
      site_id
    end

    def container_subnet
      @config.container_subnet
    end

    def container_network
      @config.container_network
    end

    def container_image
      @config.container_image
    end

    def container_htdocs
      @config.container_htdocs
    end

    def docker_compose_filename
      @config.docker_compose_filename
    end

    def web_user
      @config.web_user
    end

    def web_group
      @config.web_group
    end

    def phpfpm_port
      @config.phpfpm_port
    end

    def user_group_numeric
      uid = %x(id -u #{@config.web_user})
      gid = %x(id -g #{@config.web_user})
      "#{uid.strip}:#{gid.strip}"
    end

    def template_service_name
      @config.template_service_name
    end

    def awslogs_prefix
      status, output = Wsman::Util.cmd(@config.stack_name_cmd)
      if status == 0
        output
      else
        @config.awslogs_prefix
      end
    end

    def awslogs_config_path
      @config.awslogs_config_path
    end

    def mysql_pwd_cmd
      @config.mysql_pwd_cmd
    end

    def systemd_service_dir
      @config.systemd_service_dir
    end

    def docker_environment_dir
      @config.docker_environment_dir
    end

    def docker_environment_prefix
      @config.docker_environment_prefix
    end

    def hosting_env_file
      @config.hosting_env_file
    end

    def save
      File.write(@config_path, @config.to_yaml)
      File.chmod(@config_path, 0o600)
    end

    def deploy_env(site_name, env)
      File.write(env_file(site_name), env)
      File.chmod(env_file(site_name), 0o600)
    end

    def env_file(site_name)
      File.join(
        @config.docker_environment_dir,
        "#{@config.docker_environment_prefix}#{site_name}"
      )
    end

    def env_file_custom(site_name)
      File.join(
        @config.docker_environment_dir,
        "#{@config.docker_environment_prefix}#{site_name}-custom"
      )
    end

    private def init_db
      DB.open "sqlite3://#{@db_path}" do |db|
        db.exec "create table sites (name text PRIMARY KEY, ip_id integer)"
        db.exec "create table ips (ip text)"
        db.exec "create table dbs (site_id integer, confname text, dbname text, username text, password text)"

        insert_ips = Array(String).new
        (1..254).each do |x|
          (1..254).each do |y|
            insert_ips << "(\"#{container_subnet}#{x}.#{y}\")"
          end
        end
        db.exec "insert into ips (ip) values #{insert_ips.join(",")}"
      end
    end
  end
end
