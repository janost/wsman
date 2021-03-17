require "yaml"

module Wsman
  module Model
    class SiteConfig
      include YAML::Serializable
      @[YAML::Field(key: "phpVersion")]
      property php_version : String = "7.3"
      @[YAML::Field(key: "siteType")]
      property site_type : String = "php"
      @[YAML::Field(key: "databases")]
      property databases : Array(String) = ["main"]
      @[YAML::Field(key: "hosts")]
      property hosts : Hash(String, String) = Hash(String, String).new
      @[YAML::Field(key: "siteRoot")]
      property site_root : String = "docroot"
      @[YAML::Field(key: "solrVersion")]
      property solr_version : String = "8.8.1"
      @[YAML::Field(key: "solrCores")]
      property solr_cores : Array(String) = Array(String).new

      def initialize
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
