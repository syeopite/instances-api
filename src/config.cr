require "yaml"
require "athena"

@[ADI::Register]
class InstancesApi::Config::Provider
  # YAML Config
  struct InstancesApi::YamlConfig
    include YAML::Serializable

    @[YAML::Field(converter: URIConverter)]
    property instance_list_location : URI = URI.parse("https://raw.githubusercontent.com/iv-org/documentation/master/docs/instances.md")

    property monitor_api_key : String? = nil

    property instance_refresh_interval : Int32 = 5*60

    property http_request_timeout : Int32 = 60

    property monitor_fetch_await_timeout : Int32 = 30

    property per_instance_populate_await_timeout : Int32 = 30

    def self.load
      config = YamlConfig.from_yaml(File.read("config.yml"))
      return config
    rescue YAML::ParseException
      STDERR.puts "Unable to parse config file"
      return exit(1)
    rescue File::NotFoundError
      Log.warn { "Unable to locate configuration file. Using the default settings." }
      return YamlConfig.from_yaml("")
    ensure
      warn_msg = "monitor_api_key is required in order to fetch uptime information"
      if !config
        Log.warn { warn_msg }
      end

      if config.try(&.monitor_api_key.nil?) || false
        Log.warn { warn_msg }
      end
    end
  end

  @@config : InstancesApi::YamlConfig = InstancesApi::YamlConfig.load

  {% for method in InstancesApi::YamlConfig.methods %}
    {% if method.args.empty? %}
      def {{method.name.id}}
        return @@config.{{method.name.id}}
      end
    {% end %}
  {% end %}
end

# Taken from Invidious
module URIConverter
  def self.to_yaml(value : URI, yaml : YAML::Nodes::Builder)
    yaml.scalar value.normalize!
  end

  def self.from_yaml(ctx : YAML::ParseContext, node : YAML::Nodes::Node) : URI
    if node.is_a?(YAML::Nodes::Scalar)
      URI.parse node.value
    else
      node.raise "Expected scalar, not #{node.class}"
    end
  end
end
