require "json"
require "log"

require "athena"
require "mime"

require "./config"
require "./helpers"

require "./instances.cr"
require "./fetch.cr"
require "./extract.cr"

alias IAI = InstancesApi::Instances

require "./populate.cr"
require "./monitors.cr"

require "./templates/template.cr"

# TODO: Write documentation for `InstancesApi`
module InstancesApi
  @[ADI::Register(public: true)]
  class Controller < ATH::Controller
    def initialize(@provider : IAI::Provider, @main_page_template : InstancesApi::MainPageTemplate)
    end

    @[ARTA::Get(path: "/instances.json")]
    @[ATHA::View(emit_nil: true)]
    def instances : Array(Tuple(String, IAI::Instance))
      @provider.get &.itself
    end

    @[ARTA::Get(path: "/")]
    def index : ATH::Response
      ATH::Response.new(
        @main_page_template.render,
        headers: HTTP::Headers{"content-type" => MIME.from_extension(".html")}
      )
    end

    # Asset files
    {% for files in [{"/css/style.css", "assets/style.css"}, {"/icon.svg", "assets/icon.svg"}] %}
      {% route_path, file_location = files %}
      {% ext = "." + route_path.split(".")[-1] %}
      {% handler_name = route_path.split("/")[-1].split(".")[0] %}

      @[ARTA::Get(path: {{route_path}})]
      def {{handler_name.id}} : ATH::BinaryFileResponse
        ATH::BinaryFileResponse.new(
          {{file_location}},
          headers: HTTP::Headers{"content-type" => MIME.from_extension({{ext}})}
        )
      end

    {% end %}
  end

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
        end
      end
    end
  end
end

ADI.container.instances_api_refresh_instances_job.begin

ATH.run
