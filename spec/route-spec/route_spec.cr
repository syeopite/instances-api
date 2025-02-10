require "./route_spec_helper.cr"

Spectator.describe "Route controller" do
  it "Can return correct instances.json" do
    results = ControllerTest.new.request_instances_json_route
    File.write("results.json", results)

    results = JSON.parse(results)
    answer = get_answer_with_monitor("spec/mocks/basic/populated.json", "spec/mocks/basic/monitors.json")

    File.write("answer.json", answer.to_json)

    expect(results.as_a).to match_array(answer.as_a).in_any_order
  end
end
