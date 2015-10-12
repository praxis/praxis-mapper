module Praxis::Mapper
  # Generates a set of selectors given a resource and
  # list of resource attributes.
  class SelectorGenerator
    attr_reader :selectors

    def initialize
      @selectors = Hash.new do |hash, key|
        hash[key] = {select: Set.new, track: Set.new}
      end
    end

    def add(resource, fields)
      fields.each do |name, field|
        map_property(resource, name, field)
      end
    end

    def select_all(resource)
      selectors[resource.model][:select] = true
    end

    def map_property(resource, name, field)
      if resource.properties.key?(name)
        add_property(resource, name)
      elsif resource.model.associations.key?(name)
        add_association(resource, name, field)
      else
        add_select(resource, name)
      end
    end

    def add_select(resource, name)
      return select_all(resource) if name == :*
      return if selectors[resource.model][:select] == true

      selectors[resource.model][:select] << name
    end

    def add_track(resource, name)
      selectors[resource.model][:track] << name
    end

    def add_association(resource, name, field)
      association = resource.model.associations.fetch(name) do
        raise "missing association for #{resource} with name #{name}"
      end
      associated_resource = resource.model_map[association[:model]]

      add_track(resource, name)

      # TODO: flesh out possible association types we should handle here
      case association[:type]
      when :many_to_one
        add_select(resource, association[:key])
      when :one_to_many
        add_select(associated_resource, association[:key])
      else
        raise "no select applicable for #{association[:type].inspect}"
      end

      unless field == true
        # recurse into the field
        add(associated_resource,field)
      end
    end

    def add_property(resource, name)
      dependencies = resource.properties[name][:dependencies]
      dependencies.each do |dependency|
        apply_dependency(resource, dependency)
      end
    end

    def apply_dependency(resource, dependency)
      case dependency
      when Symbol
        map_property(resource, dependency, {})
      when String
        head, tail = dependency.split('.').collect(&:to_sym)
        raise "String dependencies can not be singular" if tail.nil?

        add_association(resource, head, {tail => true})
      end
    end

  end
end
