require "http/client"

module InstancesApi::Instances::Fetch
  module Interface
    abstract def fetch_instance_list : String
  end

  # Requests instance list from the Invidious documentation
  # and parses the result into an `IntermediateInstance`
  @[ADI::Register]
  @[ADI::AsAlias]
  struct FetchInstancesFromDocs
    include Fetch::Interface

    Client = HTTP::Client.new(URI.parse("https://raw.githubusercontent.com"))

    # Requests and parses the instances listed on https://raw.githubusercontent.com/iv-org/documentation/master/docs/instances.md
    def fetch_instance_list : String
      begin
        response = FetchInstancesFromDocs::Client.get("/iv-org/documentation/master/docs/instances.md")
        body = response.body
      rescue ex
        return ""
      end

      return body
    end
  end
end
