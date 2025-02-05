require "spectator"
require "uri"
require "athena"

alias IAI = InstancesApi::Instances

require "../src/config.cr"
require "../src/helpers.cr"

require "../src/instances.cr"
require "../src/fetch.cr"
require "../src/extract.cr"
require "../src/populate.cr"
require "../src/monitors.cr"

Config = InstancesApi::YamlConfig.from_yaml("")

# Ensure HTTP::Client is never called
#
# Taken from https://github.com/manastech/webmock.cr/blob/42b347cdd64e13193e46167a03593944ae2b3d20/src/webmock/core_ext.cr#L20
class HTTP::Client
  private def exec_internal(request : HTTP::Request)
    exec_internal(request, &.itself).tap do |response|
      response.consume_body_io
      response.headers.delete("Transfer-encoding")
      response.headers["Content-length"] = response.body.bytesize.to_s
    end
  end

  private def exec_internal(request, &block : Response -> T) : T forall T
    return HTTP::Client::Response.new(status_code = 403)
  end
end
