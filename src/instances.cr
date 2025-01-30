require "json"

# Represents a single Invidious instance
struct Instance
  include ASR::Serializable
  property url : URI
  property instance_type : String # HTTP, onion, etc
  property? region : String?
  property? flag : String?
  property? stats : JSON::Any?
  property? monitor : JSON::Any?
  property? cors : Bool?
  property? api : Bool?
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
