require 'active_support/inflector'

# A resource creates a data store and instantiates a list of models that it wishes to load, building up the overall set of data that it will need.
# Once that is complete, the data set is iterated and a resultant view is generated.
module Praxis::Mapper
  class Resource
    extend Finalizable

    attr_accessor :record
    
    # TODO: also support an attribute of sorts on the versioned resource module. ie, V1::Resources.api_version.
    #       replacing the self == Praxis::Mapper::Resource condition below.
    def self.inherited(klass)
      super

      # It is expected that each versioned set of resources will have a common Base class.
      # self is Praxis::Mapper::Resource only for Base resource classes which are versioned.
      if self == Praxis::Mapper::Resource
        klass.instance_variable_set(:@model_map, Hash.new)
      elsif defined?(@model_map)
        klass.instance_variable_set(:@model_map, @model_map)
      end
    end

    def self.model_map
      if defined? @model_map
        return @model_map
      else
        return {}
      end
    end


    #TODO: Take symbol/string and resolve the klass (but lazily, so we don't care about load order)
    def self.model(klass=nil)
      if klass
        @model = klass
        self.model_map[klass] = self
      else
        @model
      end
    end

    def self._finalize!
      finalize_resource_delegates
      define_model_accessors
      super
    end

    def self.finalize_resource_delegates
      return unless @resource_delegates

      @resource_delegates.each do |record_name, record_attributes|
        record_attributes.each do |record_attribute|
          self.define_resource_delegate(record_name, record_attribute)
        end
      end
    end


    def self.define_model_accessors
      return if model.nil?
      model.associations.each do |k,v|
        if self.instance_methods.include? k
          warn "WARNING: #{self.name} already has method named #{k.inspect}. Will not define accessor for resource association."
        end
        define_model_association_accessor(k,v)
      end
    end


    def self.for_record(record)
      return record._resource if record._resource

      if resource_class_for_record = model_map[record.class]
        return record._resource = resource_class_for_record.new(record)
      else
        version = self.name.split("::")[0..-2].join("::")
        resource_name = record.class.name.split("::").last

        raise "No resource class corresponding to the model class '#{record.class}' is defined. (Did you forget to define '#{version}::#{resource_name}'?)"
      end
    end


    def self.wrap(records)
      case records
      when Model
        return self.for_record(records)
      when nil
        # Return an empty set if `records` is nil
        return []
      else
        return records.collect { |record| self.for_record(record) }
      end
    end


    def self.get(condition)
      record = self.model.get(condition)

      self.wrap(record)
    end

    def self.all(condition={})
      records = self.model.all(condition)

      self.wrap(records)
    end


    def initialize(record)
      @record = record
    end

    def respond_to_missing?(name,*)
      @record.respond_to?(name) || super
    end

    def self.resource_delegates
      @resource_delegates ||= {}
    end

    def self.resource_delegate(spec)
      spec.each do |resource_name, attributes|
        resource_delegates[resource_name] = attributes
      end
    end

    # Defines wrapers for model associations that return Resources
    def self.define_model_association_accessor(name, association_spec)
      association_model = association_spec.fetch(:model)
      association_resource_class = model_map[association_model]
      if association_resource_class
        module_eval <<-RUBY, __FILE__, __LINE__ + 1
          def #{name}
            records = record.#{name}
            return nil if records.nil?
            @__#{name} ||= #{association_resource_class}.wrap(records)
          end
        RUBY
      end
    end

    def self.define_resource_delegate(resource_name, resource_attribute)
      related_model = model.associations[resource_name][:model]
      related_association = related_model.associations[resource_attribute]

      if related_association
        self.define_delegation_for_related_association(resource_name, resource_attribute, related_association)
      else
        self.define_delegation_for_related_attribute(resource_name, resource_attribute)
      end
    end



    def self.define_delegation_for_related_attribute(resource_name, resource_attribute)
      module_eval <<-RUBY, __FILE__, __LINE__ + 1
        def #{resource_attribute}
          @__#{resource_attribute} ||= if (rec = self.#{resource_name})
            rec.#{resource_attribute}
          end
        end
      RUBY
    end

    def self.define_delegation_for_related_association(resource_name, resource_attribute, related_association)
      related_resource_class = model_map[related_association[:model]]
      return unless related_resource_class

      module_eval <<-RUBY, __FILE__, __LINE__ + 1
        def #{resource_attribute}
          @__#{resource_attribute} ||= if (rec = self.#{resource_name})
            if (related = rec.#{resource_attribute})
              #{related_resource_class.name}.wrap(related)
            end
          end
        end
      RUBY
    end

    def self.define_accessor(name)
      if name.to_s =~ /\?/
        ivar_name = "is_#{name.to_s[0..-2]}"
      else
        ivar_name = "#{name}"
      end

      module_eval <<-RUBY, __FILE__, __LINE__ + 1
        def #{name}
          return @__#{ivar_name} if defined? @__#{ivar_name}
          @__#{ivar_name} = record.#{name}
        end
      RUBY
    end

    def method_missing(name,*args)
      if @record.respond_to?(name)
        self.class.define_accessor(name)
        self.send(name)
      else
        super
      end
    end

    def self.member_name
      @_member_name ||= self.name.split("::").last.underscore
    end

    def self.collection_name
      @_collection_name ||= self.member_name.pluralize
    end

    def member_name
      self.class.member_name
    end

    alias :type :member_name

    def collection_name
      self.class.collection_name
    end

  end
end
