# A set of model classes for use in specs
class ParentModel < Praxis::Mapper::Model
  table_name 'parent_model'
  identity :id
end


class YamlArrayModel < Praxis::Mapper::Model
  table_name 'yaml_array_model'
  identity :id

  silence_warnings do
    belongs_to :parents, :model => ParentModel,
      :source_key => :parent_ids,
      :fk => :id,
      :type => :array

    belongs_to :grandparents, :model => ParentModel,
      :source_key => :grandparent_ids,
      :fk => :id,
      :type => :array
  end

  yaml :parent_ids, :default => []
  yaml :grandparent_ids
  yaml :names

end


class JsonArrayModel < Praxis::Mapper::Model
  table_name 'json_array_model'
  identity :id

  silence_warnings do
    belongs_to :parents, :model => ParentModel,
      :source_key => :parent_ids,
      :fk => :id,
      :type => :array
  end

  json :parent_ids, :default => []
  json :names

end


class CompositeIdModel < Praxis::Mapper::Model
  table_name 'composite_id_model'
  identity [:id,:type]

  one_to_many :other_models do
    model OtherModel
    primary_key [:id, :type]
    key [:composite_id, :composite_type]
  end

  many_to_array :composite_array_models do
    model CompositeArrayModel
    primary_key [:id, :type]
    key :composite_array_keys
  end

end


class CompositeArrayModel < Praxis::Mapper::Model
  table_name 'composite_array_model'
  identity [:id,:type]


  array_to_many :composite_id_models do
    model CompositeIdModel
    primary_key [:id, :type]
    key :composite_array_keys
  end

  json :composite_array_keys

end


class OtherModel < Praxis::Mapper::Model
  table_name 'other_model'
  identity :name

  silence_warnings do
    belongs_to :composite_model, :model => CompositeIdModel,
      :source_key => [:composite_id, :composite_type],
      :fk => [:id, :type]
  end

end


class SimpleModel < Praxis::Mapper::Model
  table_name 'simple_model'
  identity :id
  identity :name

  excluded_scopes :account

  silence_warnings do
    belongs_to :parent, :model => ParentModel,
      :source_key => :parent_id,
      :fk => :id
    belongs_to :other_model, :model => OtherModel,
      :source_key => :other_name,
      :fk => :name
  end

end


class SimplerModel < Praxis::Mapper::Model
  table_name 'simpler_model'
  identity :id
  identity :name
end


class PersonModel < Praxis::Mapper::Model
  table_name 'people'

  identity :id
  identity :email

  many_to_one :address do
    model AddressModel
    key :address_id # people.address_id
  end

  one_to_many :properties do
    model AddressModel
    primary_key :id #people.id
    key :owner_id # address.owner_id
  end

  array_to_many :prior_addresses do
    model AddressModel
    key :prior_address_ids # people.prior_address_ids
  end

  json :prior_address_ids, default: []


  context :default do
    track :address
  end


  context :addresses do
    select :id, :name

    track :address do
      context :default
    end

    track :prior_addresses
  end


  context :tiny do
    select :id, :email
  end

  context :current do
    select :id
  end

end


class AddressModel  < Praxis::Mapper::Model
  table_name 'addresses'
  identity :id

  one_to_many :residents do
    model PersonModel
    key :address_id # person.address_id
  end

  many_to_one :owner do
    model PersonModel
    primary_key :id
    key :owner_id # address.owner_id
  end

  many_to_array :prior_residents do
    model PersonModel
    key :prior_address_ids # people.prior_address_ids
  end

  context :default do
    track :owner
  end

  context :current do
    track :owner do
      context :default
    end
    track :residents do
      context :tiny
    end
  end

end



class ItemModel < Praxis::Mapper::Model
  table_name 'items'
  repository_name :sql

  identity :id

  one_to_many :parts do
    model PartModel
    key :item_id # parts.item_id
  end

end


class PartModel < Praxis::Mapper::Model
  table_name 'parts'
  repository_name :sql

  identity :id

  many_to_one :item do
    model ItemModel
    key :item_id # parts.item_id
  end

end
