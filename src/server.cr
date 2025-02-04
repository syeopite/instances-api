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
  @[ADI::Register(public: true)]
  class Controller < ATH::Controller
    def initialize(@provider : IAI::Provider)
    end

    @[ARTA::Get(path: "/instances.json")]
    def root : ATH::Response
      @provider.get do |instances|
        return ATH::Response.new(
          ASR.serializer.serialize(instances, :json, context: Helpers.get_serialization_ctx),
          headers: HTTP::Headers{"content-type" => "application/json; charset=UTF-8"}
        )
      end
    end
  end

  @[ADI::Register(public: true)]
  class RefreshInstancesJob
    def initialize(@provider : IAI::Provider)
    end

    def begin
      spawn do
        instance_list = ADI.container.obtain_new_instances.fetch
        extracted_instances = ADI.container.obtain_new_instances.extract(instance_list)
        populated_instances = ADI.container.obtain_new_instances.populate(extracted_instances)

        @provider.get do |instances|
          instances.clear
          instances.replace(populated_instances)
        end
      end
    end
  end
end

ADI.container.instances_api_refresh_instances_job.begin

ATH.run
