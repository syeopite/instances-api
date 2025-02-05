require "ecr"

@[ADI::Register]
struct InstancesApi::MainPageTemplate
  def initialize(@instances : IAI::Provider)
  end

  def render
    instances = @instances
    sort_by = "placeholder"
    ECR.render("src/templates/template.ecr")
  end
end
