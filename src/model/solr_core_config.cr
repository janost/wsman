require "crinja"

module Wsman
  module Model
    @[Crinja::Attributes]
    class SolrCoreConfig
      include Crinja::Object::Auto
      getter core_id, solr_instance_id, corename, confname, solr_version
      def initialize(@core_id : Int32, @solr_instance_id : Int32, @corename : String, @confname : String, @solr_version : String)
      end
    end
  end
end
