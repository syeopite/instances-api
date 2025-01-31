module InstancesApi::Instances
  # Enum containing instance types understood by instances-api
  # Any instance that isn't explicitly supported is assumed to be clearnet

  enum InstanceType
    Onion
    I2P
    Clearnet
  end

  # Represents a single Invidious instance
  record Instance, url : URI, instance_type : InstanceType,
    region : String?, flag : String?, stats : JSON::Any?,
    monitor : JSON::Any?, cors : Bool?, api : Bool? do
    include ASR::Serializable
  end

  Helpers.create_mutex_storage("InstancesStorage", "instances", {} of String => Instance)
  INSTANCES = InstancesStorage.new

  @[ADI::Register(name: "obtain_new_instances", public: true)]
  class ObtainNewInstances
    @extractor = IAI::Extract::ExtractInstances

    def initialize(
      @fetcher : IAI::Fetch::Interface,
    )
    end

    def extract(instance_list : String)
      return @extractor.extract_instances(instance_list)
    end

    def fetch
      return @fetcher.fetch_instance_list
    end
  end
end
