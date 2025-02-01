require "uri"
require "json"

require "../spec_helper.cr"
require "../../src/populate.cr"
require "../fetch-extract-spec/fetch_extract_helper.cr"

@[ADI::Register(public: true)]
record GetTestMock, mock_file : String

struct MockQueryInstance
  include IAI::Populate::InstanceQueryInterface

  def initialize(@url : URI)
    @mock_file = JSON.parse(File.read(ADI.container.get_test_mock.mock_file))
  end

  def get(url)
    mock = @mock_file[@url.host.not_nil!]["path"][url]
    return self.response(mock)
  end

  private def response(json)
    body = json["body"].to_json()
    status_code = json["status_code"]?.try &.as_i || 200
    headers = parse_headers(json)

    return HTTP::Client::Response.new(
      status_code: status_code,
      headers: headers,
      body: body
    )
  end

  private def parse_headers(json) : HTTP::Headers?
    headers = HTTP::Headers.new

    mock_headers = json["headers"]?
    return headers if mock_headers.nil?

    mock_headers.as_h.each do | k, v |
      headers.add(k, v.as_s)
    end

    return headers
  end
end

@[ADI::Register(public: true)]
@[ADI::AsAlias(InstancesApi::Helpers::InstanceWrapperInterface)]
struct MockQueryInstanceWrapperWrapper
  include InstancesApi::Helpers::InstanceWrapperInterface

  def get : MockQueryInstance.class
    return MockQueryInstance
  end
end
