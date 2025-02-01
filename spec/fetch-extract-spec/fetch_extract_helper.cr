require "../spec_helper"

alias IIst = IAI::Extract::IntermediateInstance
alias Ist = IAI::Instance
alias IType = IAI::InstanceType

@[ADI::Register(public: true)]
@[ADI::AsAlias]
class MockFetchInstances
  include IAI::Fetch::Interface

  property file : String = ""

  def fetch_instance_list : String
    return File.read("../mocks/#{file}")
  rescue File::NotFoundError
    return ""
  end
end
