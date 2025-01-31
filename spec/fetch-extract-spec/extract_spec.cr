require "./fetch_extract_helper.cr"

@[ADI::Register(public: true)]
@[ADI::AsAlias]
class MockFetchInstances
  include IAI::Fetch::Interface

  property file : String = ""

  def fetch_instance_list : String
    return File.read("./mocks/#{file}")
  rescue File::NotFoundError
    return ""
  end
end

macro aiist(url, instance_type, region)
  IIst.new(
    URI.parse({{url}}),
    IType.parse({{instance_type.id.stringify}}),
    {{region}}.codepoints.map { |codepoint| (codepoint + 0x1f1a5).chr }.join(""),
    {{region}}
  )
end

describe IAI::Extract do
  it "Can extract instances from the instance list" do
    ADI.container.mock_fetch_instances.file = "basic-list.md"
    instance_list = ADI.container.obtain_new_instances.fetch

    ADI.container.obtain_new_instances.extract(instance_list).should eq([
      aiist("https://inv.nadeko.net", :clearnet, "CL"),
      aiist("http://inv.nadekonw7plitnjuawu6ytjsl7jlglk2t6pyq6eftptmiv3dvqndwvyd.onion", :onion, "CL"),
      aiist("http://zzlsbhhfvwg3oh36tcvx4r7n6jrw7zibvyvfxqlodcwn3mfrvzuq.b32.i2p", :i2p, "CL"),
    ])
  end
end
