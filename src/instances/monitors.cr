module IAI::Monitors
  module FetcherInterface
    def get; end
  end

  @[ADI::Register]
  @[ADI::AsAlias(IAI::Monitors::FetcherInterface)]
  class Fetcher
    include FetcherInterface

    @client : InstancesApi::Helpers::RequestClient

    def initialize(
      @config : InstancesApi::Config::Provider,
      provider : InstancesApi::Helpers::ClientProvider,
    )
      @client = provider.client(URI.parse(
        "https://updown.io"
      ))
    end

    def get : JSON::Any?
      return nil if @config.monitor_api_key.nil?

      response = (@client.get &.get("/api/checks?api-key=#{@config.monitor_api_key}"))
      if response.status_code != 200
        Log.error { "Non 200 HTTP status code #{response.status_code} when pulling uptime monitors" }
        return nil
      end

      return JSON.parse(response.body)
    rescue ex : JSON::ParseException
      Log.error { "Unable to parse the JSON for the uptime monitors: #{ex.to_s}, #{ex.message}" }
    rescue ex : Exception
      Log.error { "Error pulling uptime monitors: #{ex.to_s}, #{ex.message}" }
    end
  end
end
