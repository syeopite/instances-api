require "./monitors_spec_helper.cr"

Spectator.describe IAI::Monitors do
  def test_populate_with_monitors(list_location, instance_data_location, monitors_location)
    ADI.container.mock_fetch_instances.file = list_location

    instance_list = ADI.container.obtain_new_instances.fetch
    expect(instance_list).to ne ""

    extracted_instances = ADI.container.obtain_new_instances.extract(instance_list)

    ADI.container.mock_instance_querier_factory.mock_file = instance_data_location
    ADI.container.mock_monitor_fetcher.mock_file = monitors_location

    populated_instances = ADI.container.obtain_new_instances.populate(extracted_instances)
    return JSON.parse(ASR.serializer.serialize(populated_instances, :json, context: InstancesApi::Helpers.get_serialization_ctx))
  end

  it "Is able to populate instances with uptime monitors" do
    results = test_populate_with_monitors(
      "spec/mocks/basic/basic-list.md",
      "spec/mocks/basic/query.json",
      "spec/mocks/basic/monitors.json"
    )

    answer = get_answer_with_monitor("spec/mocks/basic/populated.json", "spec/mocks/basic/monitors.json")

    expect(results.as_a).to match_array answer.as_a
  end

  it "Can gracefully handle errors when fetching monitors" do
    results = test_populate_with_monitors(
      "spec/mocks/basic/basic-list.md",
      "spec/mocks/basic/query.json",
      "spec/mocks/basic/monitors.non-existant.json"
    )

    answer = JSON.parse(File.read("spec/mocks/basic/populated.json"))

    answer.as_a.each { |instance| expect(instance[1]["monitor"].as_nil).to be_nil }

    expect(results.as_a).to match_array answer.as_a
  end

  it "can handle incorrect JSON structure gracefully (array of json array)" do
    results = test_populate_with_monitors(
      "spec/mocks/basic/basic-list.md",
      "spec/mocks/basic/query.json",
      monitors_location: "spec/mocks/misc/incorrect-monitors-json-array.json"
    )

    raise Exception.new if !File.file?("spec/mocks/misc/incorrect-monitors-json-array.json")

    answer = JSON.parse(File.read("spec/mocks/basic/populated.json"))

    answer.as_a.each { |instance| expect(instance[1]["monitor"].as_nil).to be_nil }

    expect(results.as_a).to match_array answer.as_a
  end

  it "can handle incorrect JSON structure gracefully (different keys)" do
    results = test_populate_with_monitors(
      "spec/mocks/basic/basic-list.md",
      "spec/mocks/basic/query.json",
      monitors_location: "spec/mocks/misc/incorrect-monitors-json-diff-keys.json"
    )

    answer = JSON.parse(File.read("spec/mocks/basic/populated.json"))

    answer.as_a.each { |instance| expect(instance[1]["monitor"].as_nil).to be_nil }

    expect(results.as_a).to match_array answer.as_a
  end
end
