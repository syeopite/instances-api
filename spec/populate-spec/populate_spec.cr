require "./populate_spec_helper.cr"
require "athena"

Spectator.describe IAI::Populate::PopulateInstance do
  it "Can produce populated instance list" do
    ADI.container.mock_fetch_instances.file = "spec/mocks/basic/basic-list.md"

    instance_list = ADI.container.obtain_new_instances.fetch
    expect(instance_list).to ne ""

    extracted_instances = ADI.container.obtain_new_instances.extract(instance_list)

    ADI.container.mock_instance_querier_factory.mock_file = "spec/mocks/basic/query.json"
    populated_instances = ADI.container.obtain_new_instances.populate(extracted_instances)

    results = JSON.parse(ASR.serializer.serialize(populated_instances, :json, context: SpecHelper.serialization_ctx))
    answer = JSON.parse(File.read("spec/mocks/basic/populated.json"))

    expect(results.as_a).to match_array answer.as_a
  end

  it "Can gracefully handle request errors during instance population" do
    ADI.container.mock_fetch_instances.file = "spec/mocks/populate-request-errors/list.md"

    instance_list = ADI.container.obtain_new_instances.fetch
    expect(instance_list).to ne ""

    extracted_instances = ADI.container.obtain_new_instances.extract(instance_list)

    ADI.container.mock_instance_querier_factory.mock_file = "spec/mocks/populate-request-errors/query.json"
    populated_instances = ADI.container.obtain_new_instances.populate(extracted_instances)

    results = JSON.parse(ASR.serializer.serialize(populated_instances, :json, context: SpecHelper.serialization_ctx))
    answer = JSON.parse(File.read("spec/mocks/populate-request-errors/populated.json"))

    expect(results.as_a).to match_array answer.as_a
  end
end
