require "crinja"

module Wsman
  module Model
    @[Crinja::Attributes]
    class DbConfig
      include Crinja::Object::Auto
      getter confname, dbname, username, password
      def initialize(@confname : String, @dbname : String, @username : String, @password : String)
      end
    end
  end
end
