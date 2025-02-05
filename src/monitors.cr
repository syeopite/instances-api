module IAI::Monitors
  module MonitorFetcherInterface
    def get(); end
  end

  @[ADI::Register]
  class MonitorFetcher
    include Interface



  end
end
