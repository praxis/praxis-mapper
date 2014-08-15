# A set of resource classes for use in specs
class BaseResource < Praxis::Mapper::Resource
  def href
    base_href = '' # "/api"
    base_href + "/#{self.class.collection_name}/#{self.id}"
  end

end

class CompositeIdResource < BaseResource
  model CompositeIdModel
end

class OtherResource < BaseResource
  model OtherModel
end

class ParentResource < BaseResource
  model ParentModel
end

class SimpleResource < BaseResource
  model SimpleModel

  resource_delegate :other_model => [:other_attribute]

  def other_resource
    self.other_model
  end

end

class SimplerResource < BaseResource
  model SimplerModel
end

class YamlArrayResource < BaseResource
  model YamlArrayModel
end
