require "athena"
require "./instances.cr"
require "./fetch.cr"
require "./extract.cr"

# TODO: Write documentation for `InstancesApi`
module InstancesApi
  class Controller < ATH::Controller
    @[ARTA::Get(path: "/")]
    def root : ATH::Response
      return ATH::Response.new(
        ASR.serializer.serialize INSTANCES.instances, :json
      )
    end
  end
end

spawn do
  instance_list = ADI.container.obtain_new_instances.fetch
  extracted_instances = ADI.container.obtain_new_instances.extract(instance_list)
end

ATH.run
