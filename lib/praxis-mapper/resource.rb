require 'active_support/inflector'

# A resource creates a data store and instantiates a list of models that it wishes to load, building up the overall set of data that it will need.
# Once that is complete, the data set is iterated and a resultant view is generated.
module Praxis::Mapper

  class ResourceDecorator < BasicObject
    def initialize(parent, object)
      @parent = parent
      @object = object # store obj for future use
    end

    def respond_to_missing?(name, include_private = false)
      @object.respond_to?(name, include_private) || super
    end

    def method_missing(name,*args, &block)
      @object.__send__(name, *args, &block)
    end

    def __getobj__
      @object
    end
  end


  class Resource
    extend Finalizable

    attr_accessor :record

    @properties = {}

    class << self
      attr_reader :model_map
      attr_reader :decorations
      attr_reader :properties
    end

    # TODO: also support an attribute of sorts on the versioned resource module. ie, V1::Resources.api_version.
    #       replacing the self.superclass == Praxis::Mapper::Resource condition below.
    def self.inherited(klass)
      super

      klass.instance_eval do
        # It is expected that each versioned set of resources
        # will have a common Base class, and so should share
        # a model_map
        if self.superclass == Praxis::Mapper::Resource
          @model_map = Hash.new
        else
          @model_map = self.superclass.model_map
        end

        @decorations = {}
        @properties = self.superclass.properties.clone
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


    def self.decorate(name, &block)
      self.decorations[name] = Class.new(ResourceDecorator, &block)
    end

    def self.property(name, **options)
      self.properties[name] = options
    end

    def self._finalize!
      finalize_resource_delegates
      define_model_accessors
      define_decorators

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


    def self.define_decorators
      self.decorations.each do |name,block|
        self.define_decorator(name, block)
      end
    end

    def self.define_decorator(name, block)
      unless self.instance_methods.include?(name)
        # assume it'll be a regular accessor and create it
        self.define_accessor(name)
      end
      # alias original method and wrap it
      raw_name = "_raw_#{name}"
      alias_method(raw_name.to_sym, name)

      module_eval <<-RUBY, __FILE__, __LINE__ + 1
        def #{name}
          object = self.#{raw_name}
          self.class.decorations[#{name.inspect}].new(self, object)
        end
      RUBY
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
      when nil
        return []
      when Enumerable
        return records.compact.collect { |record| self.for_record(record) }
      else
        return self.for_record(records)
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


    def self.resource_delegates
      @resource_delegates ||= {}
    end

    def self.resource_delegate(spec)
      spec.each do |resource_name, attributes|
        resource_delegates[resource_name] = attributes
      end
    end

    # Defines wrappers for model associations that return Resources
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


    def initialize(record)
      @record = record
    end

    def respond_to_missing?(name,*)
      @record.respond_to?(name) || super
    end

    def method_missing(name,*args)
      if @record.respond_to?(name)
        self.class.define_accessor(name)
        self.send(name)
      else
        super
      end
    end

  end
end
