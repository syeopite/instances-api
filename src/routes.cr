require "./templates/template.cr"

@[ADI::Register(public: true)]
class InstancesApi::Controller < ATH::Controller
  def initialize(@provider : IAI::Provider, @main_page_template : InstancesApi::MainPageTemplate)
  end

  @[ARTA::Get(path: "/instances.json")]
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
