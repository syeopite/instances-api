require "uri"
require "json"

require "../spec_helper.cr"
require "../../src/populate.cr"
require "../fetch-extract-spec/fetch_extract_helper.cr"

# Simulates requests by fetching the data from a mock file instead
# instead of HTTP requests to a remote server
struct MockInstanceQuerier
  include IAI::Populate::InstanceQuerierInterface

  def initialize(@url : URI, mock_file_path : String)
    @mock_file = JSON.parse File.read(mock_file_path)
  end

  def get(url)
    mock = @mock_file[@url.host.not_nil!]["path"][url]
    return self.response(mock)
  end

  private def response(json)
    if json["error"]?
      raise Exception.new
    end

    if json["body"]?
      body = json["body"].to_json
    else
      body = "{}"
    end

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

struct MockInstanceQuerierBuilder
  def initialize(@mock_file : String)
  end

  def new(url : URI)
    return MockInstanceQuerier.new(url, @mock_file)
  end
end

@[ADI::Register(public: true)]
@[ADI::AsAlias(InstancesApi::Helpers::InstanceWrapperInterface)]
# A factory service that returns an MockInstanceQuerierBuilder to construct MockInstanceQuerier instances
#
# Exposes a mock_file setter to change where the `MockInstanceQuerier` retrieves its data from.
class MockInstanceQuerierFactory
  include InstancesApi::Helpers::InstanceWrapperInterface

  property mock_file : String = ""

  def get
    return MockInstanceQuerierBuilder.new(@mock_file)
  end
end
