require "json"
require "log"

require "athena"
require "mime"

require "./config"
require "./helpers"
require "./routes.cr"

alias IAI = InstancesApi::Instances
require "./instances/*"

# TODO: Write documentation for `InstancesApi`
module InstancesApi
  @[ADI::Register(public: true)]
  class RefreshInstancesJob
    def initialize(@config : InstancesApi::Config::Provider, @provider : IAI::Provider)
    end

    def begin
      spawn do
        Log.info { " Fetching initial instance list " }

        loop do
          instance_list = ADI.container.obtain_new_instances.fetch
          extracted_instances = ADI.container.obtain_new_instances.extract(instance_list)
          populated_instances = ADI.container.obtain_new_instances.populate(extracted_instances)

          @provider.get do |instances|
            instances.clear
            instances.replace(populated_instances)
          end

          Log.info { "Finished refreshing instance list. Sleeping for #{@config.instance_refresh_interval.seconds}" }
          sleep @config.instance_refresh_interval.seconds
          Log.info { " Begin refreshing instance list " }
        rescue ex : Exception
          Log.error { " An unknown error has occurred while refreshing instances: #{ex}, #{ex.message}. Retrying in #{@config.instance_refresh_interval.seconds} " }
          sleep @config.instance_refresh_interval.seconds
        end
      end
    end
  end
end

ADI.container.instances_api_refresh_instances_job.begin

ATH.configure({
  framework: {
    view_handler: {
      serialize_nil: true,
    },
  },
})

ATH.run
