require "./populate_spec_helper.cr"

describe IAI::Populate do
  it "Can produce populated instance list" do
    ADI.container.mock_fetch_instances.file = "basic/basic-list.md"
    instance_list = ADI.container.obtain_new_instances.fetch
    extracted_instances = ADI.container.obtain_new_instances.extract(instance_list)
    ADI.bind mock_file, "spec/mocks/basic/query.json"
    populated_instances = ADI.container.obtain_new_instances.populate(extracted_instances)

    results = JSON.parse(ASR.serializer.serialize(populated_instances, :json))
    answer = JSON.parse(File.read("spec/mocks/basic/populated.json"))

    results.as_h.should eq answer.as_h
  end
end
