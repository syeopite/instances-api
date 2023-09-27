# Background job to fetch and update instance information

struct InstanceRefreshJob
  def begin
    spawn do
      refreshed_instances_api_data = self.refresh_instances
      INSTANCES.clear
      INSTANCES.merge! refreshed_instances_api_data

      sleep 5.minutes
      Fiber.yield
    end
  end

  private def refresh_instances
    # Get monitors
    monitor_channel = Channel(Array(JSON::Any)).new

    # Get instance stats
    instance_stats_channel = Channel(Hash(String, Instance)).new

    spawn do
      monitor_channel.send(get_uptime_monitors)
    end

    spawn do
      instance_stats_channel.send(get_instances_stats)
    end

    select
    when monitors = monitor_channel.receive
    when timeout 5.minute # Timeout for fetching *all* uptime monitors
    # TODO select old monitors


    end

    select
    when instances_stats_map = instance_stats_channel.receive
    when timeout 20.minute # Timeout for fetching *all* instance /api/v1/stats endpoint
    # TODO select old instances list


    end

    monitors = monitors.not_nil!
    instances_stats_map = instances_stats_map.not_nil!

    # Attach uptime monitor to instance stats

    # Map url to uptime monitor
    monitors_map = {} of String => JSON::Any | Instance
    monitors.each do |m|
      monitors_map[m["name"].as_s] = m
    end

    # The uptime tracker also keeps track of instances in-approval and sometimes also instances
    # that got deleted from the official list but did not get removed from the tracker yet.
    # Thus we need to filter those out.
    officially_sanctioned_instances = monitors_map.keys - instances_stats_map.keys
    officially_sanctioned_instances.each { |k| monitors_map.delete(k) }

    # Merge monitors and instance stats
    instances_api_data = monitors_map
    instances_api_data.merge!(instances_stats_map) do |host, monitor, stats|
      Instance.new(
        flag: stats["flag"],
        region: stats["region"],
        stats: stats["stats"],
        cors: stats["cors"],
        api: stats["api"],
        type: stats["type"],
        uri: stats["uri"].to_s,
        monitor: monitor.as(JSON::Any)
      )
    end

    # Restrict type from
    # Hash(String, JSON::Any || Instance) to Hash(String, Instance)
    instances_api_data = instances_api_data.transform_values { |instance_data| instance_data.as(Instance) }

    return instances_api_data
  end

  private def get_instances_stats
    instances = {} of String => Instance
    instance_stats_transfer_channel = Channel(Tuple(String, Instance)).new

    count = 0

    self.get_each_instance do |raw_instance_definition|
      count += 1

      spawn do
        instance_stats_transfer_channel.send(fetch_instance_stats(raw_instance_definition))
      end
    end

    count.times do
      select
      when transfer = instance_stats_transfer_channel.receive
        host, stats = transfer
        instances[host] = stats
      when timeout 30.second # Timeout for parsing stats of a single instance


      end
    end

    return instances
  end

  private def fetch_instance_stats(raw_instance_definition)
    uri = URI.parse(raw_instance_definition["uri"])
    host = raw_instance_definition["host"]
    region = raw_instance_definition["region"]?.try { |region| region.codepoints.map { |codepoint| (codepoint - 0x1f1a5).chr }.join("") }
    flag = raw_instance_definition["region"]?

    type = host.split(".")[-1]

    case type
    when "onion"
    when "i2p"
    else
      type = uri.scheme.as(String)
      client = HTTP::Client.new(uri)
      client.connect_timeout = 10.seconds
      client.read_timeout = 10.seconds

      begin
        stats = JSON.parse(client.get("/api/v1/stats").body)
      rescue ex : Exception
        stats = nil
      end

      # Get API and CORS status
      cors = false
      api = false

      begin
        trending = client.get("/api/v1/trending")

        if trending.status_code == 200
          cors = (trending.headers["Access-Control-Allow-Origin"] == "*")

          trending = JSON.parse(trending.body)
          trending[0]["videoId"].as_s

          api = true
        end
      rescue ex : Exception
        # TODO log unable to parse API/CORS status
      end
    end

    # Basically an instance named tuple but without the monitor attached
    return host, {
      flag:    flag,
      region:  region,
      stats:   stats,
      cors:    cors,
      api:     api,
      type:    type,
      uri:     uri.to_s,
      monitor: nil,
    }
  end

  private def get_each_instance(&)
    begin
      body = HTTP::Client.get(URI.parse("https://raw.githubusercontent.com/iv-org/documentation/master/docs/instances.md")).body
    rescue ex
      body = "" # TODO
    end

    body = body.split("### Blocked:")[0] # TODO error handle here
    body.scan(/\[(?<host>[^ \]]+)\]\((?<uri>[^\)]+)\)( .(?<region>[\x{1f100}-\x{1f1ff}]{2}))?/mx).each do |md|
      yield md
    end
  end

  private def get_uptime_monitors
    initial_page = fetch_uptime_api_info(1)
    psp = initial_page["psp"]
    monitors = psp["monitors"].as_a

    page = 1
    remaining_pages = (psp["totalMonitors"].as_i / psp["perPage"].as_i).ceil.to_i - 1

    channel = Channel(JSON::Any).new

    remaining_pages.times do
      page += 1
      spawn fetch_uptime_api_info(page, channel)
    end

    remaining_pages.times do
      response = channel.receive
      monitors += response["psp"]["monitors"].as_a
    end

    return monitors
  end

  private def fetch_uptime_api_info(page, channel : Channel? = nil)
    client = HTTP::Client.new(URI.parse("https://stats.uptimerobot.com"))
    client.connect_timeout = 10.seconds
    client.read_timeout = 10.seconds

    response = JSON.parse(client.get("/api/getMonitorList/89VnzSKAn?page=#{page}").body)

    if channel
      return channel.send(response)
    else
      return response
    end
  end
end
