module InstancesApi::Extract
  # Intermediate object representing a instance listed on the documentation
  # This means that we'll only have URL, scheme and region to go off of before
  # additional requests populate the other fields
  struct IntermediateInstance
    property url : URI
    property instance_type : InstanceType # HTTP, onion, etc
    property? flag : String?
    property? region : String?

    def initialize(@url, @instance_type, @flag, @region)
    end
  end

  module ExtractInstances
    extend self

    # Parses the raw markdown of the instance list to produce an array of IntermediateInstance
    def extract_instances(body) : Array(IntermediateInstance)
      intermediate_instances = [] of IntermediateInstance

      body.scan(/\[(?<host>[^ \]]+)\]\((?<uri>[^\)]+)\)( .(?<region>[\x{1f100}-\x{1f1ff}]{2}))?/mx).each do |md|
        url = URI.parse(md["uri"])
        flag = md["region"]?
        region = md["region"]?.try { |region| region.codepoints.map { |codepoint| (codepoint - 0x1f1a5).chr }.join("") }

        instance_type = self.identify_instance_type(url)

        intermediate_instances << IntermediateInstance.new(
          url, instance_type, flag, region
        )
      end

      return intermediate_instances
    end

    # Identifies the type of the instance via the URL eg clearnet, onion, etc.
    private def identify_instance_type(url : URI) : InstanceType
      type_identifier = url.host.try &.split(".")[-1]

      if !type_identifier.nil?
        return InstanceType.parse?(type_identifier) || InstanceType::Clearnet
      end

      return InstanceType::Clearnet
    end
  end
end
