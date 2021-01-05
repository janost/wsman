require "yaml"

module Wsman
  module Model
    class SiteConfig
      getter site_root

      DEFAULT_PHP_VERSION = "7.3"
      DEFAULT_SITE_TYPE = "php"
      DEFAULT_DATABASES = ["main"]
      DEFAULT_HOSTS = Hash(String, String).new
      DEFAULT_SITE_ROOT = "docroot"
      DEFAULT_SOLR_VERSION = nil
      DEFAULT_SOLR_CORES = Array(String).new

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
          type:    Hash(String, String),
          nilable: false,
          default: DEFAULT_HOSTS,
          setter:  false,
        },
        site_root: {
          type: String,
          key: "siteRoot",
          nilable: false,
          default: DEFAULT_SITE_ROOT,
          setter: false,
        },
        solr_version: {
          type:    String,
          key:     "solrVersion",
          nilable: true,
          default: DEFAULT_SOLR_VERSION,
          setter:  false,
        },
        solr_cores: {
          type:    Array(String),
          key:     "solrCores",
          nilable: false,
          default: DEFAULT_SOLR_CORES,
          setter:  false,
        }
      )

      def initialize
        @php_version = DEFAULT_PHP_VERSION
        @site_type = DEFAULT_SITE_TYPE
        @databases = DEFAULT_DATABASES
        @hosts = DEFAULT_HOSTS
        @site_root = DEFAULT_SITE_ROOT
        @solr_version = DEFAULT_SOLR_VERSION
        @solr_cores = DEFAULT_SOLR_CORES
      end

      def full_hosts(base_domain)
        result = Hash(String, String).new
        @hosts.each do |host, _folder|
          host = host.gsub(/[^0-9a-z]/i, '_')
          result[host.upcase] = "#{host}.#{base_domain}"
        end
        result
      end
    end
  end
end
