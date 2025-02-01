require "spec"
require "uri"
require "athena"

alias IAI = InstancesApi::Instances

require "../src/config.cr"
require "../src/helpers.cr"

require "../src/instances.cr"
require "../src/fetch.cr"
require "../src/extract.cr"
require "../src/populate.cr"

Config = InstancesApi::YamlConfig.from_yaml("")
