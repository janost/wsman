require "yaml"
require "sqlite3"

require "./model/db_config"
require "./model/solr_core_config"

module Wsman
  class Config
    DEFAULT_NGINX_CONF_DIR = "/etc/nginx"
    DEFAULT_WEB_ROOT_DIR = "/srv/www"
    DEFAULT_CONTAINER_SUBNET = "172.28."
    DEFAULT_CONTAINER_NETWORK = "web"
    DEFAULT_CONTAINER_IMAGE = "cheppers/php"
    DEFAULT_CONTAINER_HTDOCS = "/htdocs"
    DEFAULT_DOCKER_COMPOSE_FILENAME = "docker-compose.yml"
    DEFAULT_WEB_USER = "web"
    DEFAULT_WEB_GROUP = "web"
    DEFAULT_PHPFPM_PORT = 9000
    DEFAULT_TEMPLATE_SERVICE_NAME = "wsd"
    DEFAULT_AWSLOGS_PREFIX = "simple-webhost"
    DEFAULT_AWSLOGS_CONFIG_PATH = "/var/awslogs/etc/config"
    DEFAULT_MYSQL_PWD_CMD = "/opt/get-db-password.sh"
    DEFAULT_SYSTEMD_SERVICE_DIR = "/etc/systemd/system"
    DEFAULT_DOCKER_ENVIRONMENT_DIR = "/etc/wsman-sites"
    DEFAULT_DOCKER_ENVIRONMENT_PREFIX = "wsd-"
    DEFAULT_HOSTING_ENV_FILE = "/etc/wsman-sites/hosting-env"
    DEFAULT_STACK_NAME_CMD = "/opt/stack-name.sh"
    DEFAULT_SOLR_IMAGE = "solr"
    DEFAULT_SOLR_DATA_PATH = "/data/solr_instances"

    YAML.mapping(
      nginx_conf_dir: {
        type:    String,
        default: DEFAULT_NGINX_CONF_DIR,
      },
      fixtures_dir: {
        type:    String,
        default: "#{ENV["HOME"]}/.config/wsman/fixtures",
      },
      web_root_dir: {
        type:    String,
        default: DEFAULT_WEB_ROOT_DIR,
      },
      docker_compose_filename: {
        type:    String,
        default: DEFAULT_DOCKER_COMPOSE_FILENAME,
      },
      container_image: {
        type:    String,
        default: DEFAULT_CONTAINER_IMAGE,
      },
      container_htdocs: {
        type:    String,
        default: DEFAULT_CONTAINER_HTDOCS,
      },
      container_subnet: {
        type:    String,
        default: DEFAULT_CONTAINER_SUBNET,
      },
      container_network: {
        type:    String,
        default: DEFAULT_CONTAINER_NETWORK,
      },
      web_user: {
        type:    String,
        default: DEFAULT_WEB_USER,
      },
      web_group: {
        type:    String,
        default: DEFAULT_WEB_GROUP,
      },
      phpfpm_port: {
        type:    Int32,
        default: DEFAULT_PHPFPM_PORT,
      },
      template_service_name: {
        type:    String,
        default: DEFAULT_TEMPLATE_SERVICE_NAME,
      },
      awslogs_prefix: {
        type:    String,
        default: DEFAULT_AWSLOGS_PREFIX,
      },
      awslogs_config_path: {
        type:    String,
        default: DEFAULT_AWSLOGS_CONFIG_PATH,
      },
      mysql_pwd_cmd: {
        type:    String,
        default: DEFAULT_MYSQL_PWD_CMD,
      },
      systemd_service_dir: {
        type:    String,
        default: DEFAULT_SYSTEMD_SERVICE_DIR,
      },
      docker_environment_dir: {
        type:    String,
        default: DEFAULT_DOCKER_ENVIRONMENT_DIR,
      },
      docker_environment_prefix: {
        type:    String,
        default: DEFAULT_DOCKER_ENVIRONMENT_PREFIX,
      },
      hosting_env_file: {
        type:    String,
        default: DEFAULT_HOSTING_ENV_FILE,
      },
      stack_name_cmd: {
        type:    String,
        default: DEFAULT_STACK_NAME_CMD,
      },
      solr_image: {
        type:    String,
        default: DEFAULT_SOLR_IMAGE,
      },
      solr_data_path: {
        type:    String,
        default: DEFAULT_SOLR_DATA_PATH,
      }
    )

    def initialize(config_base)
      @nginx_conf_dir = DEFAULT_NGINX_CONF_DIR
      @fixtures_dir = File.join(config_base, "fixtures")
      @web_root_dir = DEFAULT_WEB_ROOT_DIR
      @container_subnet = DEFAULT_CONTAINER_SUBNET
      @container_network = DEFAULT_CONTAINER_NETWORK
      @container_image = DEFAULT_CONTAINER_IMAGE
      @container_htdocs = DEFAULT_CONTAINER_HTDOCS
      @docker_compose_filename = DEFAULT_DOCKER_COMPOSE_FILENAME
      @web_user = DEFAULT_WEB_USER
      @web_group = DEFAULT_WEB_GROUP
      @phpfpm_port = DEFAULT_PHPFPM_PORT
      @template_service_name = DEFAULT_TEMPLATE_SERVICE_NAME
      @awslogs_prefix = DEFAULT_AWSLOGS_PREFIX
      @awslogs_config_path = DEFAULT_AWSLOGS_CONFIG_PATH
      @mysql_pwd_cmd = DEFAULT_MYSQL_PWD_CMD
      @systemd_service_dir = DEFAULT_SYSTEMD_SERVICE_DIR
      @docker_environment_dir = DEFAULT_DOCKER_ENVIRONMENT_DIR
      @docker_environment_prefix = DEFAULT_DOCKER_ENVIRONMENT_PREFIX
      @hosting_env_file = DEFAULT_HOSTING_ENV_FILE
      @stack_name_cmd = DEFAULT_STACK_NAME_CMD
      @solr_image = DEFAULT_SOLR_IMAGE
      @solr_data_path = DEFAULT_SOLR_DATA_PATH
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
      Dir.mkdir_p(@config.solr_data_path) unless Dir.exists?(@config.solr_data_path)
      @wsman_version = "0.1"
    end

    def db_path
      @db_path
    end

    def nginx_conf_dir
      @config.nginx_conf_dir
    end

    def fixtures_dir
      @config.fixtures_dir
    end

    def web_root_dir
      Dir.mkdir_p(@config.web_root_dir)
      @config.web_root_dir
    end

    def container_ip(instance_name, instance_db_table)
      ip_id = nil
      ip = nil
      return ip unless instance_name
      DB.open "sqlite3://#{@db_path}" do |db|
        db.query "SELECT ip_id FROM #{instance_db_table} WHERE name = ?", instance_name do |rs|
          rs.each do
            ip_id = rs.read(Int32)
          end
        end
        if ip_id.nil?
          db.query "SELECT rowid, ip FROM ips WHERE rowid NOT IN (SELECT ip_id FROM sites UNION SELECT ip_id FROM solr_instances) ORDER BY rowid LIMIT 1" do |rs|
            rs.each do
              ip_id = rs.read(Int32)
              ip = rs.read(String)
            end
          end
          db.exec "INSERT OR IGNORE INTO #{instance_db_table} (name) VALUES (?)", instance_name
          db.exec "UPDATE #{instance_db_table} SET ip_id = ? WHERE name = ?", ip_id, instance_name
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

    def delete_site_config(site_name)
      Wsman::Util.remove_file(env_file(site_name))
      DB.open "sqlite3://#{@db_path}" do |db|
        site_id = db_site_id(db, site_name)
        db.exec "DELETE FROM sites WHERE rowid = ?", site_id
        db.exec "DELETE FROM dbs WHERE site_id = ?", site_id
      end
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

    def get_solr_instance_id(version)
      solr_instance = nil
      DB.open "sqlite3://#{@db_path}" do |db|
        db.query "SELECT rowid FROM solr_instances WHERE name = ? LIMIT 1", version do |rs|
          rs.each do
            solr_instance = rs.read(Int32)
          end
        end
      end
      solr_instance
    end

    def has_solr_container?(solr_version)
      ! get_solr_instance_id(solr_version).nil?
    end

    def get_solr_cores_from_db(site_name)
        solr_cores = Array(Wsman::Model::SolrCoreConfig).new
        DB.open "sqlite3://#{@db_path}" do |db|
          site_id = db_site_id(db, site_name)
          return solr_cores unless site_id

          db.query "SELECT sc.rowid,sc.solr_instance_id,sc.corename,sc.confname,si.name FROM solr_cores sc LEFT JOIN solr_instances si WHERE sc.site_id = ?", site_id do |rs|
            rs.each do
              core_id = rs.read(Int32)
              solr_instance_id = rs.read(Int32)
              corename = rs.read(String)
              confname = rs.read(String)
              solr_version = rs.read(String)
              solr_cores << Wsman::Model::SolrCoreConfig.new(core_id, solr_instance_id, corename, confname.upcase, solr_version)
            end
          end
        end
        solr_cores
    end

    def add_solr_config_to_db(confname, site_name, solr_version)
      corename = generate_solr_corename(confname, site_name)
      DB.open "sqlite3://#{@db_path}" do |db|
        site_id = db_site_id(db, site_name)
        solr_instance_id = get_solr_instance_id(solr_version)
        db.exec "INSERT OR IGNORE INTO solr_cores (corename, site_id, confname, solr_instance_id) "\
                "VALUES (?, ?, ?, ?)", corename, site_id, confname, solr_instance_id
      end
      corename
    end

    def update_solr_core_site_id(site_name, corename)
      DB.open "sqlite3://#{@db_path}" do |db|
        site_id = db_site_id(db, site_name)
        db.exec "UPDATE solr_cores SET site_id = ? WHERE corename = ?", site_id, corename
      end
    end

    def solr_core_exists?(solr_cores, corename)
      solr_core_names = solr_cores.map { |c| c.corename }
      solr_core_names.includes? corename
    end

    def solr_version_name(solr_version)
      solr_version_name=""
      if solr_version
        solr_version_name = solr_version.gsub(/[^0-9a-z]/i, '_')
      end
      solr_version_name
    end

    def create_or_update_solr_container(solr_version, dcompose)
      if solr_dcompose_changed?(solr_version, dcompose)
        cores_path = solr_cores_path_by_version(solr_version)
        Dir.mkdir_p(cores_path)
        File.chown(cores_path, uid: 8983, gid: 8983)
        save_solr_dcompose(solr_version, dcompose)
      end
    end

    def create_solr_core(solr_version, corename, solr_core_config_dir)
      cores_path = solr_cores_path_by_version(solr_version)
      core_conf_path = File.join(cores_path, corename)
      Dir.mkdir_p(core_conf_path)
      Wsman::Util.cmd("rm", ["-rf", File.join(core_conf_path, "conf")])
      Wsman::Util.cmd("cp", ["-rp", solr_core_config_dir, core_conf_path])
      File.write(File.join(core_conf_path, "core.properties"), "name=#{corename}")
      Dir["#{cores_path}/**/*"].each do |path|
        File.chown(path, uid: 8983, gid: 8983)
      end
    end

    def solr_dcompose_changed?(solr_version, dcompose)
      dc_file = solr_dcompose_file(solr_version)
      if File.exists?(dc_file)
        current_dc = File.read(dc_file)
        dcompose != current_dc
      else
        true
      end
    end

    def save_solr_dcompose(solr_version, dcompose)
      File.write(solr_dcompose_file(solr_version), dcompose)
    end

    def solr_dcompose_file(solr_version)
      File.join(solr_data_path, solr_version_name(solr_version), docker_compose_filename)
    end

    def solr_cores_path_by_version(solr_version)
      File.join(solr_data_path, solr_version_name(solr_version), "cores")
    end

    def delete_solr_cores(solr_cores)
      solr_cores.each do |solr_core|
        cores_path = solr_cores_path_by_version(solr_core.solr_version)
        core_path = File.join(cores_path, solr_core.corename)
        Wsman::Util.remove_file(core_path)
      end
    end

    def delete_solr_instance(solr_version)
      solr_version_path = File.join(solr_data_path, solr_version_name(solr_version))
      Wsman::Util.remove_file(solr_version_path)
    end

    def remove_solr_cores_from_db(site_name)
      DB.open "sqlite3://#{@db_path}" do |db|
        site_id = db_site_id(db, site_name)
        db.exec "DELETE FROM solr_cores WHERE site_id = ?", site_id
      end
    end

    def remove_solr_instance_from_db(solr_version)
      DB.open "sqlite3://#{@db_path}" do |db|
        solr_instance_id = get_solr_instance_id(solr_version)
        db.exec "DELETE FROM solr_instances WHERE rowid = ?", solr_instance_id
      end
    end

    def solr_instance_has_cores?(solr_instance_id)
      instance_id = nil
      DB.open "sqlite3://#{@db_path}" do |db|
        db.query "SELECT rowid FROM solr_cores WHERE solr_instance_id = ?", solr_instance_id do |rs|
          rs.each do
            instance_id = rs.read(Int32)
          end
        end
      end
      !instance_id.nil?
    end

    def generate_solr_corename(confname, site_name)
      "#{confname.upcase}_#{site_name.gsub('-', '_').gsub('.', '_')}"
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

    def solr_image
      @config.solr_image
    end

    def solr_data_path
      @config.solr_data_path
    end

    def save
      File.write(@config_path, @config.to_yaml)
      File.chmod(@config_path, 0o600)
    end

    def env_changed?(site_name, new_env)
      if File.exists?(env_file(site_name))
        current_env = File.read(env_file(site_name))
        new_env != current_env
      else
        true
      end
    end

    def deploy_env(site_name, env)
      File.write(env_file(site_name), env)
      File.chmod(env_file(site_name), 0o644)
      gid = Wsman::Util.get_gid_for("web")
      File.chown(env_file(site_name), gid: gid)
    end

    def env_file(site_name)
      File.join(
        @config.docker_environment_dir,
        "#{@config.docker_environment_prefix}#{site_name}"
      )
    end

    # All -<postfix> postfixed envfile
    def env_files_custom(site_name)
      Dir["#{@config.docker_environment_dir}/#{@config.docker_environment_prefix}#{site_name}-*"]
    end

    private def init_db
      DB.open "sqlite3://#{@db_path}" do |db|
        db.exec "create table sites (name text PRIMARY KEY, ip_id integer)"
        db.exec "create table ips (ip text)"
        db.exec "create table dbs (site_id integer, confname text, dbname text, username text, password text)"
        db.exec "create table solr_instances (name text PRIMARY KEY, ip_id integer)"
        db.exec "create table solr_cores (corename text PRIMARY KEY, site_id integer, confname text, solr_instance_id integer)"

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
