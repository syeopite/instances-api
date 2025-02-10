require "../spec_helper.cr"

require "athena/spec"
require "../../src/routes.cr"

require "../monitors-spec/monitors_spec_helper.cr"

# Needed to call get_answer_with_monitor within a class
def local_get_answer_with_monitor(answer_location, monitor_location)
  get_answer_with_monitor(answer_location, monitor_location)
end

@[ADI::Register(public: true)]
struct InstancesProviderProviderService
  property provider

  def initialize(@provider : IAI::Provider)
  end
end

# Tests /instance.json route and whether it returns the proper instances json
struct ControllerTest < ATH::Spec::APITestCase
  def request_instances_json_route : String
    ADI.container.mock_fetch_instances.file = "spec/mocks/basic/basic-list.md"
    ADI.container.mock_instance_querier_factory.mock_file = "spec/mocks/basic/query.json"
    ADI.container.mock_monitor_fetcher.mock_file = "spec/mocks/basic/monitors.json"

    instance_list = ADI.container.obtain_new_instances.fetch
    extracted_instances = ADI.container.obtain_new_instances.extract(instance_list)
    populated_instances = ADI.container.obtain_new_instances.populate(extracted_instances)

    provider = ADI.container.instances_provider_provider_service.provider

    provider.get do |instances|
      instances.clear
      instances.replace(populated_instances)
    end

    return self.get("/instances.json").body
  end
end

ATH.configure({
  framework: {
    view_handler: {
      serialize_nil: true,
    },
  },
})
