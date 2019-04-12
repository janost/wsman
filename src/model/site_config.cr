require "yaml"

module Wsman
  module Model
    class SiteConfig
      YAML.mapping(
        php_version: {
          type:    String,
          key:     "phpVersion",
          nilable: false,
          default: "7.2",
          setter:  false,
        },
        site_type: {
          type:    String,
          key:     "siteType",
          nilable: false,
          default: "php",
          setter:  false,
        },
        databases: {
          type:    Array(String),
          nilable: false,
          default: ["main"],
          setter:  false,
        },
        hosts: {
          type:    Array(String),
          nilable: false,
          default: Array(String).new,
          setter:  false,
        },
      )
    end
  end
end
