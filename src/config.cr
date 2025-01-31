require "yaml"

# YAML Config
struct InstancesApi::YamlConfig
  include YAML::Serializable

  @[YAML::Field(converter: URIConverter)]
  property instance_list_location : URI = URI.parse("https://raw.githubusercontent.com/iv-org/documentation/master/docs/instances.md")

  def self.load
    config = YamlConfig.from_yaml(File.read("config.yml"))
    return config
  rescue YAML::ParseException
    STDERR.puts "Unable to parse config file"
    return exit(1)
  rescue File::NotFoundError
    Log.warn { "**WARNING** Unable to locate configuration file. Using the default settings." }
    return YamlConfig.from_yaml("")
  end
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
