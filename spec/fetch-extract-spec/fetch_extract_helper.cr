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
    return File.read(@file)
  rescue File::NotFoundError
    Log.info { "mock file #{@file} not found" }
    return ""
  end
end
