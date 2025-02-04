require "uri"
require "json"

require "../spec_helper.cr"
require "../../src/populate.cr"
require "../fetch-extract-spec/fetch_extract_helper.cr"

# Simulates requests by fetching the data from a mock file instead
# instead of HTTP requests to a remote server
struct MockQueryInstance
  include IAI::Populate::InstanceQueryInterface

  def initialize(@url : URI, mock_file_path : String)
    @mock_file = JSON.parse File.read(mock_file_path)
  end

  def get(url)
    mock = @mock_file[@url.host.not_nil!]["path"][url]
    return self.response(mock)
  end

  private def response(json)
    body = json["body"].to_json
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

    mock_headers.as_h.each do |k, v|
      headers.add(k, v.as_s)
    end

    return headers
  end
end

# Wrapper around `MockQueryInstance` that provides a location of a mock file
# to the `MockQueryInstance`
struct MockQueryInstanceWrapper
  def initialize(@mock_file : String)
  end

  def new(url : URI)
    return MockQueryInstance.new(url, @mock_file)
  end
end

@[ADI::Register(public: true)]
@[ADI::AsAlias(InstancesApi::Helpers::InstanceWrapperInterface)]
# Wrapper around a wrapper that initializes MockQueryInstance
#
# The original implementation wraps one layer due to `PopulateInstance` needing
# to initialize `QueryInstance` with a url, and ADI services always being initialized.
#
# The mock implementation however also needs to pass the location of the mock data file
# into the `MockQueryInstance` object. And considering `MockQueryInstance` is used
# in a new Fiber, we cannot register and modify it through ADI.container from a test block.
#
# As such we provide the mock file location to this outermost wrapper, which provides compatibility
# with how `QueryInstanceWrapper` is used by creating an intermediate object holding the location with
# a faux `#new` constructor method that will finally initialize a `MockQueryInstance` with both the given url
# and the location of the mock data.
class MockQueryInstanceWrapperWrapper
  include InstancesApi::Helpers::InstanceWrapperInterface

  property mock_file : String = ""

  def get
    return MockQueryInstanceWrapper.new(@mock_file)
  end
end
