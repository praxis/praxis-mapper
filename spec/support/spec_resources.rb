# A set of resource classes for use in specs
class BaseResource < Praxis::Mapper::Resource
  def href
    base_href = '' # "/api"
    base_href + "/#{self.class.collection_name}/#{self.id}"
  end

  property :href, dependencies: [:id]
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

  property :other_resource, dependencies: [:other_model]

  property :name, dependencies: [:simple_name]
end

class SimplerResource < BaseResource
  model SimplerModel
end

class YamlArrayResource < BaseResource
  model YamlArrayModel
end


class PersonResource < BaseResource
  model PersonModel

  decorate :address do
    def href
      @parent.href + "/address"
    end
  end

  decorate :properties do
    def href
      @parent.href + "/properties"
    end
  end

  def href
    "/people/#{self.id}"
  end

end

class AddressResource < BaseResource
  model AddressModel


  def href
    "/addresses/#{self.id}"
  end
  property :href, dependencies: [:id]

  def owner_name
    self.owner.name
  end
  property :owner_name, dependencies: ['owner.name']

  def resident_count
    self.residents.size
  end
  property :resident_count, dependencies: [:residents]

end
