require "http/client"

module InstancesApi::Instances::Fetch
  module Interface
    abstract def fetch_instance_list : String
  end

  # Requests instance list from the Invidious documentation
  # and parses the result into an `IntermediateInstance`
  @[ADI::Register(_client: HTTP::Client.new(Config.instance_list_location))]
  @[ADI::AsAlias]
  # Use class for now until https://github.com/athena-framework/athena/issues/512 is fixed
  class FetchInstancesFromDocs
    include Fetch::Interface

    def initialize(@client : HTTP::Client)
    end

    # Requests and parses the instances given with
    def fetch_instance_list : String
      begin
        response = @client.get("/iv-org/documentation/master/docs/instances.md")
        body = response.body
      rescue ex
        return ""
      end

      return body
    end
  end
end
