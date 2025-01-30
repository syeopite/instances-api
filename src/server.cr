require "athena"
require "./instances.cr"

# TODO: Write documentation for `InstancesApi`
module InstancesApi
  class Controller < ATH::Controller
    @[ARTA::Get(path: "/")]
    def root : ATH::Response
      return ATH::Response.new("Hello world")
    end
  end
end

ATH.run
