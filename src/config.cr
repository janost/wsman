require "yaml"

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
      site_config: {
        type:    Hash(String, Hash(String, String | Int32 | Nil)),
        default: Hash(String, Hash(String, String | Int32 | Nil)).new,
        #default: {} of String => {} of String => String | Int32 | Nil,
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
      stack_name_cmd: {
        type:    String,
        default: "/opt/stack-name.sh",
      },
    )

    def initialize(config_base)
      @nginx_conf_dir = "/etc/nginx"
      @fixtures_dir = File.join(config_base, "fixtures")
      @web_root_dir = "/srv/www"
      @site_config = Hash(String, Hash(String, String | Int32 | Nil)).new
      # Currently we're limited to a /24 subnet
      @container_subnet = "172.28.200."
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
      @stack_name_cmd = "/opt/stack-name.sh"
    end
  end

  class ConfigManager
    FIRST_CONTAINER_IP = 10
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
      unless @config.site_config.has_key?(site_name)
        @config.site_config[site_name] = Hash(String, String | Int32 | Nil).new
      end
      unless @config.site_config[site_name]["container_ip"]?
        @config.site_config[site_name]["container_ip"] = next_container_ip
        save
      end
      @config.site_config[site_name]["container_ip"]
    end

    def has_db_config?(site_name)
      unless @config.site_config.has_key?(site_name)
        @config.site_config[site_name] = Hash(String, String | Int32 | Nil).new
      end
      @config.site_config[site_name]["db_name"]? || 
        @config.site_config[site_name]["db_username"]? || 
        @config.site_config[site_name]["db_password"]?
    end

    def set_db_config(site_name, db_name, db_username, db_password)
      unless @config.site_config.has_key?(site_name)
        @config.site_config[site_name] = Hash(String, String | Int32 | Nil).new
      end
      @config.site_config[site_name]["db_name"] = db_name
      @config.site_config[site_name]["db_username"] = db_username
      @config.site_config[site_name]["db_password"] = db_password
      save
    end

    def get_db_config(site_name)
      unless @config.site_config.has_key?(site_name)
        @config.site_config[site_name] = Hash(String, String | Int32 | Nil).new
      end
      {
        @config.site_config[site_name]["db_name"]?,
        @config.site_config[site_name]["db_username"]?,
        @config.site_config[site_name]["db_password"]?
      }
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
      status, output = run_cmd(@config.stack_name_cmd)
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

    def save
      File.write(@config_path, @config.to_yaml)
      File.chmod(@config_path, 0o600)
    end
    
    private def next_container_ip
      ips = Array(Int32).new
      @config.site_config.each do |k, v|
        if v["container_ip"]? != nil
          ips << v["container_ip"].as(Int32)
        end
      end
      if ips.size == 0
        FIRST_CONTAINER_IP
      else
        ips.sort!
        ips.last + 1
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
