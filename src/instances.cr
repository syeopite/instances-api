require "wait_group"

module InstancesApi::Instances
  # Enum containing instance types understood by instances-api
  # Any instance that isn't explicitly supported is assumed to be clearnet

  enum InstanceType
    Onion
    I2P
    Clearnet
  end

  # Represents a single Invidious instance
  @[ASRA::AccessorOrder(:custom, order: ["flag", "region", "stats", "cors", "api", "type", "uri", "monitor"])]
  struct Instance
    include ASR::Serializable

    alias TYPE = JSON::Any | URI | InstanceType | String | Bool | Nil

    @[ASRA::IgnoreOnDeserialize]
    @[ASRA::IgnoreOnSerialize]
    property url : URI

    @[ASRA::IgnoreOnDeserialize]
    @[ASRA::IgnoreOnSerialize]
    property instance_type : InstanceType

    property region : String?
    property flag : String?

    property stats : JSON::Any?
    property monitor : JSON::Any?
    property cors : Bool?
    property api : Bool?

    @[ASRA::VirtualProperty]
    @[ASRA::Name(serialize: "type")]
    def get_instance_type : String
      return "https" if instance_type == InstanceType::Clearnet
      return @instance_type.to_s.downcase
    end

    @[ASRA::VirtualProperty]
    @[ASRA::Name(serialize: "uri")]
    def get_url : String
      return @url.host.not_nil!
    end

    # Constructs a fully populated `Instance` object from an `IntermediateInstance` and `InstanceData`
    def self.construct(
      intermediate_instance : IAI::Extract::IntermediateInstance,
      instance_data : IAI::Populate::InstanceData?,
      monitor_data : JSON::Any?,
    )
      args = {} of String => Instance::TYPE

      args["url"] = intermediate_instance.url
      args["instance_type"] = intermediate_instance.instance_type
      args["region"] = intermediate_instance.region
      args["flag"] = intermediate_instance.flag

      if instance_data
        args["stats"] = instance_data.stats
        args["cors"] = instance_data.cors
        args["api"] = instance_data.api
      end

      args["monitor"] = monitor_data

      return self.new(
        url: args["url"].as(URI),
        instance_type: args["instance_type"].as(InstanceType),
        region: args["region"].as(String?),
        flag: args["flag"].as(String?),
        stats: args["stats"]?.as(JSON::Any?),
        cors: args["cors"]?.as(Bool?),
        api: args["api"]?.as(Bool?),
        monitor: args["monitor"].as(JSON::Any?),
      )
    end

    def initialize(@url, @instance_type, @region, @flag, @stats, @monitor, @cors, @api)
    end
  end

  @[ADI::Register(name: "instances_provider")]
  # Provides parsed list of instances
  struct Provider
    Helpers.create_mutex_storage("InstancesStorage", "instances", [] of {String, Instance})
    private INSTANCES = InstancesStorage.new

    def get(&)
      INSTANCES.get { | instances | yield instances }
    end
  end

  @[ADI::Register(name: "obtain_new_instances", public: true)]
  class ObtainNewInstances
    @extractor = IAI::Extract::ExtractInstances

    def initialize(
      @config : InstancesApi::Config::Provider,
      @fetcher : IAI::Fetch::Interface,
      @instance_querier : InstancesApi::Helpers::InstanceWrapperInterface,
      @uptime_monitor_fetcher : IAI::Monitors::FetcherInterface,
    )
    end

    private macro begin_rescue_block(message,  &block)
      begin
        {{block.body}}
      rescue ex : Exception
        Log.error { "#{ {{message}} } #{ex.to_s}, #{ex.message}" }
      end
    end

    def populate(intermediate_instances : Array(Extract::IntermediateInstance))
      intermediate_instances_hash = {} of String => Extract::IntermediateInstance
      intermediate_instances.each { |aiist| intermediate_instances_hash[aiist.url.host.not_nil!] = aiist }

      # Receives parsed uptime monitors from the spawned fiber
      monitor_channel = Channel(JSON::Any?).new

      spawn { monitor_channel.send(@uptime_monitor_fetcher.get()) }

      # A string means that we weren't able to populate the instance so
      # we should just use the data of the intermediate instance
      channel = Channel(String | Tuple(String, Populate::InstanceData)).new

      intermediate_instances.each do |inter_inst|
        host = inter_inst.url.host.not_nil!

        spawn do
          case inter_inst.instance_type
          when InstanceType::Clearnet
            instance_querier = @instance_querier.get.new(inter_inst.url)
            populator = Populate::PopulateInstance.new(host, instance_querier)
            channel.send(populator.obtain)
          else
            channel.send(host)
          end
        rescue ex : Exception
          Log.error { "An error occurred when fetching instance data #{ex.to_s}, #{ex.message}" }
          channel.send(host)
        end
      end

      # Monitors should be retrieved first when

      monitors = nil
      begin_rescue_block(
        "An error occurred when awaiting uptime monitors",
      ) do
        select
        when monitors = monitor_channel.receive
        when timeout(@config.monitor_fetch_await_timeout.seconds)
          monitors = nil
        end
      end

      monitors = monitors.try &.as_a?

      full_instances = [] of {String, Instance}

      begin_rescue_block("An error occurred when awaiting instance data population") do
        intermediate_instances.size.times do
          select
          when package = channel.receive
            if package.is_a? String
              host = package
              instance_data = nil
            else
              host, instance_data = package
            end

            # Identify specific uptime monitor for the instance
            monitor = monitors.try &.select { |monitor| monitor.as_h?.try &.["alias"]?.try &.as_s == host }[0]?

            aiist = intermediate_instances_hash[host]
            full_instances << {host, Instance.construct(aiist, instance_data, monitor)}
          when timeout(@config.per_instance_populate_await_timeout.seconds)
            Log.error { "A timeout occurred when trying to populate an instance" }
          end
        end
      end

      return full_instances
    end

    def extract(instance_list : String)
      return @extractor.extract_instances(instance_list)
    end

    def fetch
      return @fetcher.fetch_instance_list
    end
  end
end
