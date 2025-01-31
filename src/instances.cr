require "json"

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

# Allows accessing instances in a thread-safe manner
class InstancesStorage
  @mutex : Mutex

  def initialize(@instances = {} of String => Instance)
    @mutex = Mutex.new
  end

  def instances
    self.instances do |processed_instances|
      return processed_instances
    end
  end

  def instances(&)
    @mutex.lock
    begin
      yield @instances
    ensure
      @mutex.unlock
    end
  end
end

INSTANCES = InstancesStorage.new

@[ADI::Register(name:"obtain_new_instances", public: true)]
class ObtainNewInstances
  @extractor = InstancesApi::Extract::ExtractInstances

  def initialize(
    @fetcher : InstancesApi::Fetch::Interface,
  )
  end

  def extract(instance_list : String)
    return @extractor.extract_instances(instance_list)
  end

  def fetch()
    return @fetcher.fetch_instance_list
  end
end
