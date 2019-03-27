require "../config"
require "../error/site_validation_exception"

require "crinja"

module Wsman
  module Model
    class Site
      getter site_name

      def initialize(@config : Wsman::ConfigManager, @site_name : String)
        @site_root = File.join(@config.web_root_dir, site_name)
        prepare_dirs
      end

      def render_nginx
        template = crinja_template("nginx-site.conf.j2")
        template.render(template_values)
      end

      def needs_dcompose?
        site_type_file = File.join(subdir("wsconfig"), "site-type")
        if File.exists?(site_type_file)
          site_type = File.read(site_type_file).strip
          site_type != "static"
        else
          true
        end
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

      def has_valid_cert?
        Dir["#{subdir("cert")}/*.crt"].size == 1 && Dir["#{subdir("cert")}/*.key"].size == 1
      end

      private def prepare_dirs
        subdir("wsconfig")
        subdir("htdocs")
        subdir("cert")
        subdir("log")
        subdir("templates")
      end

      private def subdir(dir : String)
        full_path = File.join(@site_root, dir)
        Dir.mkdir_p(full_path) unless Dir.exists?(full_path)
        full_path
      end

      private def crinja_template(template_name)
        env = Crinja.new
        if File.exists?(File.join(subdir("templates"), template_name))
          env.loader = Crinja::Loader::FileSystemLoader.new(subdir("templates"))
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
        db_name, db_username, db_password = @config.get_db_config(site_name)
        {
          "container_image" => @config.container_image,
          "user_group_numeric" => @config.user_group_numeric,
          "web_root_dir" => @config.web_root_dir,
          "container_htdocs" => @config.container_htdocs,
          "container_network" => @config.container_network,
          "site_name" => site_name,
          "container_ip" => "#{@config.container_ip(@site_name)}",
          "phpfpm_port" => @config.phpfpm_port,
          "gen_time" => Time.now,
          "wsman_version" => @config.wsman_version,
          "cert_path" => cert_path,
          "cert_key_path" => cert_key_path,
          "awslogs_prefix" => @config.awslogs_prefix,
          "db_name" => db_name,
          "db_username" => db_username,
          "db_password" => db_password,
          "needs_dcompose" => needs_dcompose?,
          "tls_enabled" => has_valid_cert?
        }
      end
    end
  end
end
