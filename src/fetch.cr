require "http/client"

module InstancesApi::Instances::Fetch
  module Interface
    abstract def fetch_instance_list : String
  end

  # Requests instance list from the Invidious documentation
  # and parses the result into an `IntermediateInstance`
  #
  # Use class for now until https://github.com/athena-framework/athena/issues/512 is fixed
  @[ADI::Register]
  @[ADI::AsAlias]
  class FetchInstancesFromDocs
    include Fetch::Interface

    @client : InstancesApi::Helpers::RequestClient

    def initialize(
      config :   InstancesApi::Config::Provider,
      provider : InstancesApi::Helpers::ClientProvider
    )
      @client = provider.client(config.instance_list_location)
    end

    # Requests and parses the instances given with
    def fetch_instance_list : String
      begin
        response = @client.get &.get("/iv-org/documentation/master/docs/instances.md")
        body = response.body
      rescue ex
        return ""
      end

      return body
    end
  end
end
