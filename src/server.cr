require "log"

require "athena"

require "./config"
require "./helpers"

require "./instances.cr"
require "./fetch.cr"
require "./extract.cr"

Config = InstancesApi::YamlConfig.load

alias IAI = InstancesApi::Instances

# TODO: Write documentation for `InstancesApi`
module InstancesApi
  class Controller < ATH::Controller
    @[ARTA::Get(path: "/instances.json")]
    def root : ATH::Response
      IAI::INSTANCES.get do | instances |
        return ATH::Response.new(
          ASR.serializer.serialize(instances, :json),
          headers: HTTP::Headers{"content-type" => "application/json; charset=UTF-8"}
        )
      end
    end
  end
end

spawn do
  instance_list = ADI.container.obtain_new_instances.fetch
  extracted_instances = ADI.container.obtain_new_instances.extract(instance_list)

  IAI::INSTANCES.get do |instances|
    instances.clear

    extracted_instances.each do |extracted_instance|
      instances[extracted_instance.url.to_s] = IAI::Instance.new(
        extracted_instance.url,
        extracted_instance.instance_type,
        extracted_instance.region,
        extracted_instance.flag,
        nil,
        nil,
        nil,
        nil
      )
    end
  end
end

ATH.run
