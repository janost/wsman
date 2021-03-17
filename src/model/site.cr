require "../config"
require "../error/site_validation_exception"
require "./site_config"

require "crinja"
require "yaml"

module Wsman
  module Model
    class Site
      getter site_name
      getter siteconf
      getter skip_solr
      setter skip_solr

      DIR_TEMPLATES = "ws-template"
      DIR_CONFIG = "ws-config"
      SITECONF_FILE = "site.yml"
      DIR_SOLR_CORES = "solr-cores"

      def initialize(@config : Wsman::ConfigManager, @site_name : String)
        @site_root = File.join(@config.web_root_dir, site_name)
        @skip_solr = false
        prepare_dirs
        if File.exists?(File.join(subdir(DIR_CONFIG), SITECONF_FILE))
          @siteconf = SiteConfig.from_yaml(File.read(File.join(subdir(DIR_CONFIG), SITECONF_FILE)))
        else
          @siteconf = SiteConfig.new
        end
      end

      def render_nginx
        template = crinja_template("nginx-site.conf.j2")
        template.render(template_values)
      end

      def needs_dcompose?
        @siteconf.try &.site_type != "static"
      end

      def render_dcompose
        template = crinja_template("docker-compose.yml.j2")
        template.render(template_values)
      end

      def render_awslogs
        template = crinja_template("awslogs.conf.j2")
        template.render(template_values)
      end

      def render_site_env
        template = crinja_template("site-environment.j2")
        template.render(template_values)
      end

      def render_solr_dcompose
        template = crinja_template("docker-compose-solr.yml.j2")
        template.render(template_values)
      end

      def dcompose_changed?
        dc_file = File.join(@site_root, @config.docker_compose_filename)
        if File.exists?(dc_file)
          current_dc = File.read(dc_file)
          render_dcompose != current_dc
        else
          true
        end
      end

      def save_dcompose
        File.write(File.join(@site_root, @config.docker_compose_filename), render_dcompose)
      end

      def solr_core_config_dir(confname)
        solr_core_conf_dir = File.join(@site_root, DIR_CONFIG, DIR_SOLR_CORES, confname, "conf")
        if File.exists?(solr_core_conf_dir)
          solr_core_conf_dir
        else
          nil
        end
      end

      def has_valid_cert?
        Dir["#{subdir("cert")}/*.crt"].size == 1 && Dir["#{subdir("cert")}/*.key"].size == 1
      end

      def env_file
        @config.env_file(@site_name)
      end

      def env_files_custom
        @config.env_files_custom(@site_name)
      end

      private def prepare_dirs
        subdir("htdocs")
        subdir("cert")
        subdir("log")
        subdir(DIR_TEMPLATES)
        subdir(DIR_CONFIG)
      end

      private def subdir(dir : String)
        full_path = File.join(@site_root, dir)
        Dir.mkdir_p(full_path) unless Dir.exists?(full_path)
        full_path
      end

      private def crinja_template(template_name)
        env = Crinja.new
        if File.exists?(File.join(subdir(DIR_TEMPLATES), template_name))
          env.loader = Crinja::Loader::FileSystemLoader.new(subdir(DIR_TEMPLATES))
        else
          env.loader = Crinja::Loader::FileSystemLoader.new(File.join(@config.fixtures_dir, "templates"))
        end
        env.get_template(template_name)
      end

      private def cert_path
        crt_files = Dir["#{subdir("cert")}/*.crt"]
        if crt_files.size == 1
          crt_files.first
        else
          nil
        end
      end

      private def cert_key_path
        key_files = Dir["#{subdir("cert")}/*.key"]
        if key_files.size == 1
          key_files.first
        else
          nil
        end
      end

      private def template_values
        env_files = Array(String).new
        env_files << @config.hosting_env_file if File.exists?(@config.hosting_env_file)
        env_files << env_file if File.exists?(env_file)
        if env_files_custom.any?
          env_files_custom.each do |env_file_custom|
            env_files << env_file_custom if File.exists?(env_file_custom)
          end
        end
        {
          "container_image" => @config.container_image,
          "user_group_numeric" => @config.user_group_numeric,
          "web_root_dir" => @config.web_root_dir,
          "container_htdocs" => @config.container_htdocs,
          "container_network" => @config.container_network,
          "site_name" => site_name,
          "container_ip" => "#{@config.container_ip(@site_name, "sites")}",
          "phpfpm_port" => @config.phpfpm_port,
          "gen_time" => Time.local,
          "wsman_version" => @config.wsman_version,
          "cert_path" => cert_path,
          "cert_key_path" => cert_key_path,
          "awslogs_prefix" => @config.awslogs_prefix,
          "databases" => @config.get_db_config(@site_name),
          "needs_dcompose" => needs_dcompose?,
          "tls_enabled" => has_valid_cert?,
          "env_files" => env_files,
          "php_version" => @siteconf.php_version,
          "extra_hosts" => @siteconf.full_hosts(@site_name),
          "site_root" => File.join("htdocs", @siteconf.site_root || ""),
          "solr_enabled" => !skip_solr,
          "solr_image" => @config.solr_image,
          "solr_version" => @siteconf.solr_version,
          "solr_version_name" => @config.solr_version_name(@siteconf.solr_version),
          "solr_container_ip" => @config.container_ip(@siteconf.solr_version, "solr_instances"),
          "solr_cores" => @config.get_solr_cores_from_db(@site_name),
          "solr_data_path" => @config.solr_data_path
        }
      end
    end
  end
end
