require "../spec_helper.cr"
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
    Log.info { "mock file #{mock_file} for mock uptime monitors not found" }
    return nil
  rescue ex : Exception
    Log.error { "Error retrieving mock uptime monitor: #{ex}, #{ex.message}" }
    return nil
  end
end

def get_answer_with_monitor(answer_location, monitor_location)
  answer = JSON.parse(File.read(answer_location))
  uptime_monitors = JSON.parse(File.read(monitor_location))

  answer.as_a.each do |instances|
    host, data = instances
    instance_monitor = uptime_monitors.as_a.try &.select { |monitor| monitor["alias"]?.try &.as_s == host }[0]?
    data.as_h["monitor"] = instance_monitor if instance_monitor
  end

  return answer
end
