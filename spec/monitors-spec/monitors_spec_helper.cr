require "../spec_helper.cr"
require "../../src/populate.cr"
require "../fetch-extract-spec/fetch_extract_helper.cr"
require "../populate-spec/populate_spec.cr"

@[ADI::Register(public: true)]
@[ADI::AsAlias(IAI::Monitors::FetcherInterface)]
# Disables monitor fetching for the populate instance tests
class MockMonitorFetcher
  include IAI::Monitors::FetcherInterface

  property mock_file : String? = nil

  def get
    return nil if !(mock_file = @mock_file)
    return JSON.parse(File.read(mock_file))
  rescue File::NotFoundError
    Log.info { "mock file #{mock_file} not found" }
    return nil
  rescue ex : Exception
    Log.error { "Error pulling uptime monitors: #{ex.to_s}, #{ex.message}" }
    return nil
  end
end

def get_answer_with_monitor(answer_location, monitor_location)
  answer = JSON.parse(File.read(answer_location))
  uptime_monitors = JSON.parse(File.read(monitor_location))

  answer.as_a.each do |instances|
    host, data = instances
    monitor = uptime_monitors.as_a.try &.select { |monitor| monitor["alias"]?.try &.as_s == host }[0]?
    data.as_h["monitor"] = monitor if monitor
  end

  return answer
end
