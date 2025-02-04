require "./fetch_extract_helper.cr"

macro aiist(url, instance_type, region)
  IIst.new(
    URI.parse({{url}}),
    IType.parse({{instance_type.id.stringify}}),
    {{region}}.codepoints.map { |codepoint| (codepoint + 0x1f1a5).chr }.join(""),
    {{region}}
  )
end

Spectator.describe IAI::Extract do
  it "Can extract instances from the instance list" do
    ADI.container.mock_fetch_instances.file = "spec/mocks/basic/basic-list.md"
    instance_list = ADI.container.obtain_new_instances.fetch

    expect(ADI.container.obtain_new_instances.extract(instance_list)).to eq([
      aiist("https://inv.nadeko.net", :clearnet, "CL"),
      aiist("http://inv.nadekonw7plitnjuawu6ytjsl7jlglk2t6pyq6eftptmiv3dvqndwvyd.onion", :onion, "CL"),
      aiist("http://zzlsbhhfvwg3oh36tcvx4r7n6jrw7zibvyvfxqlodcwn3mfrvzuq.b32.i2p", :i2p, "CL"),
    ])
  end

  it "Can handle request failures gracefully when fetching instances" do
    # Non-existant mock files causes an caught exception in `MockFetchInstances`, when then
    # returns an empty string
    ADI.container.mock_fetch_instances.file = "spec/mocks/non-existant/list.md"
    instance_list = ADI.container.obtain_new_instances.fetch

    expect(instance_list).to eq("")
    expect(ADI.container.obtain_new_instances.extract(
      instance_list
    )).to eq([] of IIst)
  end
end
