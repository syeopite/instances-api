require "json"
require "log"

require "athena"

require "./config"
require "./helpers"

require "./instances.cr"
require "./fetch.cr"
require "./extract.cr"

alias IAI = InstancesApi::Instances

require "./populate.cr"

Config = InstancesApi::YamlConfig.load

# TODO: Write documentation for `InstancesApi`
module InstancesApi
  class Controller < ATH::Controller
    @[ARTA::Get(path: "/instances.json")]
    def root : ATH::Response
      IAI::INSTANCES.get do |instances|
        return ATH::Response.new(
          ASR.serializer.serialize(instances, :json, context: Helpers.get_serialization_ctx),
          headers: HTTP::Headers{"content-type" => "application/json; charset=UTF-8"}
        )
      end
    end
  end
end

spawn do
  instance_list = ADI.container.obtain_new_instances.fetch
  extracted_instances = ADI.container.obtain_new_instances.extract(instance_list)
  populated_instances = ADI.container.obtain_new_instances.populate(extracted_instances)

  IAI::INSTANCES.get do |instances|
    instances.clear
    instances.replace(populated_instances)
  end
end

ATH.run
