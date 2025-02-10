# The populate module requests the instance to obtain various information about the instance.
# Each request is done in its own fiber and communicated via channels.
module IAI::Populate
  module InstanceQuerierInterface
    abstract def get(url)
  end

  # Requests an instance to obtain stats, api availability, and cors status
  struct InstanceQuerier
    include InstanceQuerierInterface

    @client : Helpers::RequestClient

    def initialize(@client_provider : InstancesApi::Helpers::ClientProvider, url : URI)
      @client = client_provider.client(url)
    end

    def get(url)
      return @client.get &.get(url)
    end
  end

  @[ADI::Register]
  # Constructs instances of `InstanceQuerier`
  struct InstanceQuerierBuilder
    def initialize(@client_provider : InstancesApi::Helpers::ClientProvider)
    end

    # Constructs a new instance of `InstanceQuerier` with the given url
    def new(url : URI)
      return InstanceQuerier.new(@client_provider, url)
    end
  end

  @[ADI::Register]
  @[ADI::AsAlias(InstancesApi::Helpers::InstanceWrapperInterface)]
  # A factory service that returns an InstanceQuerierBuilder to construct InstanceQuerier instances
  #
  # This convoluted pathway allows `PopulateInstance` to initialize `InstanceQuerier` with a uri
  # and also allows us to inject the ClientProvider service into it
  class InstanceQuerierFactory
    include InstancesApi::Helpers::InstanceWrapperInterface

    def initialize(@instance_querier_builder : IAI::Populate::InstanceQuerierBuilder)
    end

    def get
      return @instance_querier_builder
    end
  end

  # Fetched data returned from an instance. Nil represents a failure to obtain that info
  record InstanceData, stats : JSON::Any?, api : Bool?, cors : Bool?

  struct PopulateInstance
    def initialize(@host : String, @instance_querier : InstanceQuerierInterface)
    end

    # Use @instance_querier to request /api/v1/stats
    private def get_stats
      stats = @instance_querier.get("/api/v1/stats")
      return JSON.parse(stats.body)
    rescue
      return nil
    end

    # Check /api/v1/trending for API availability
    #
    # API is presumed to be disabled when the status code is not 200
    # or when a videoId failed to be extracted from the JSON response
    #
    # TODO: Check multiple endpoints to assess availability
    private def check_api
      trending = @instance_querier.get("/api/v1/trending")

      begin
        if trending.status_code == 200
          trending = JSON.parse(trending.body)
          check = trending.as_a?.try &.[0]["videoId"].try &.as_s

          return check.is_a? String
        end
      rescue ex : JSON::ParseException | KeyError | IndexError
        return false
      end

      return false
    rescue
      return nil
    end

    private def check_cors
      response = @instance_querier.get("/api/v1/trending")
      return (response.headers["Access-Control-Allow-Origin"]?.try { |h| h == "*" }) || false
    rescue
      return nil
    end

    def obtain : Tuple(String, InstanceData)
      stats = self.get_stats
      api = self.check_api
      cors = self.check_cors

      return @host, InstanceData.new(stats, api, cors)
    end
  end
end
