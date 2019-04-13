require "yaml"

module Wsman
  module Model
    class SiteConfig
      DEFAULT_PHP_VERSION = "7.2"
      DEFAULT_SITE_TYPE = "php"
      DEFAULT_DATABASES = ["main"]
      DEFAULT_HOSTS = Array(String).new

      YAML.mapping(
        php_version: {
          type:    String,
          key:     "phpVersion",
          nilable: false,
          default: DEFAULT_PHP_VERSION,
          setter:  false,
        },
        site_type: {
          type:    String,
          key:     "siteType",
          nilable: false,
          default: DEFAULT_SITE_TYPE,
          setter:  false,
        },
        databases: {
          type:    Array(String),
          nilable: false,
          default: DEFAULT_DATABASES,
          setter:  false,
        },
        hosts: {
          type:    Array(String),
          nilable: false,
          default: DEFAULT_HOSTS,
          setter:  false,
        },
      )

      def initialize
        @php_version = DEFAULT_PHP_VERSION
        @site_type = DEFAULT_SITE_TYPE
        @databases = DEFAULT_DATABASES
        @hosts = DEFAULT_HOSTS
      end

      def full_hosts(base_domain)
        result = Hash(String, String).new
        @hosts.each do |host|
          result[host.upcase] = "#{host}.#{base_domain}"
        end
        result
      end
    end
  end
end
