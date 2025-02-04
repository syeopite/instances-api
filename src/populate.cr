# The populate module requests the instance to obtain various information about the instance.
# Each request is done in its own fiber and communicated via channels.
module IAI::Populate
  module InstanceQueryInterface
    abstract def get(url)
  end

  # Requests an instance to obtain stats, api availability, and cors status
  struct QueryInstance
    include InstanceQueryInterface

    @client : Helpers::RequestClient

    def initialize(url : URI)
      if !(host = url.host)
        raise Exception.new
      end

      client = nil

      Helpers::RequestClients.get do |clients|
        if client = clients[host]?
        else
          client = Helpers::RequestClient.new(url)
          clients[host] = client
        end
      end

      raise Exception.new if client.nil?
      @client = client
    end

    def get(url)
      return @client.get &.get(url)
    end
  end

  @[ADI::Register]
  @[ADI::AsAlias(InstancesApi::Helpers::InstanceWrapperInterface)]
  {%
  # Note: QueryInstanceWrapper is a class due to an upstream bug in Athena dependency injection
  # that prevents other interfaces from being a class unless the default implement is a class
  %}
  # This allows `PopulateInstance` to initialize `QueryInstance` with a URI
  class QueryInstanceWrapper
    include InstancesApi::Helpers::InstanceWrapperInterface

    def get
      return QueryInstance
    end
  end

  # Fetched data returned from an instance. Nil represents a failure to obtain that info
  record InstanceData, stats : JSON::Any?, api : Bool?, cors : Bool?

  struct PopulateInstance
    def initialize(@host : String, @query_instance : InstanceQueryInterface)
    end

    # Use @query_instance to request /api/v1/stats
    private def get_stats
      stats = @query_instance.get("/api/v1/stats")
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
      trending = @query_instance.get("/api/v1/trending")

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
      response = @query_instance.get("/api/v1/trending")
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
