# -*- coding: utf-8 -*-
# This is an abstract class.
# Does not have any ORM logic, but instead relies on a data store repository.

module Praxis::Mapper
  class Model
    extend Finalizable
  
    attr_accessor :_resource, :identity_map, :_query

    class << self
      attr_accessor  :_identities
      attr_reader :associations, :config, :serialized_fields, :contexts
    end

    def self.inherited(klass)
      super

      klass.instance_eval do
        @config = {
          excluded_scopes: [],
          identities: []
        }
        @associations = {}
        @serialized_fields = {}
        @contexts = Hash.new
      end
    end

    # Internal finalize! logic
    def self._finalize!
      self.define_data_accessors *self.identities.flatten

      self.associations.each do |name,config|
        self.associations[name] = config.to_hash
      end

      self.define_associations

      super
    end

    # Implements Praxis::Mapper DSL directive 'excluded_scopes'.
    # Gets or sets the excluded scopes for this model.
    # Exclusion means that the named condition cannot be applied.
    #
    # @param *scopes [Array] list of scopes to exclude
    # @return [Array] configured list of scopes
    # @example excluded_scopes :account, :deleted_at
    def self.excluded_scopes(*scopes)
      if scopes.any?
        self.config[:excluded_scopes] = scopes
      else
        self.config.fetch(:excluded_scopes)
      end
    end

    # Gets or sets the repository for this model.
    #
    # @param name [Symbol] repository name
    # @return [Symbol] repository name or :default
    def self.repository_name(name=nil)
      if name
        self.config[:repository_name] = name
      else
        self.config.fetch(:repository_name, :default)
      end
    end

    # Implements Praxis::Mapper DSL directive 'table_name'.
    # Gets or sets the SQL-like table name.
    # Can also be thought of as a namespace in the repository.
    #
    # @param name [Symbol] table name
    # @return [Symbol] table name or nil
    # @example table_name 'json_array_model'
    def self.table_name(name=nil)
      if name
        self.config[:table_name] = name
      else
        self.config.fetch(:table_name, nil)
      end
    end

    # Implements Praxis::Mapper DSL directive 'belongs_to'.
    # If name and belongs_to_options are given, upserts the association.
    # If only name is given, gets the named association.
    # Else, returns all configured associations.
    #
    # @param name [String] name of association to set or get
    # @param belongs_to_options [Hash] new association options
    # @option :model [Model] the associated model
    # @option :fk [String] associated field name
    # @option :source_key [String] local field name
    # @option :type [Symbol] type of mapping, :scalar or :array
    # @return [Array] all configured associations
    # @example
    #    belongs_to :parents, :model => ParentModel,
    #        :source_key => :parent_ids,
    #        :fk => :id,
    #        :type => :array
    def self.belongs_to(name=nil, belongs_to_options={})
      if !belongs_to_options.empty?
        warn "DEPRECATION: `#{self}.belongs_to` is deprecated. Use `many_to_one` or `array_to_many` instead."

        opts = {:fk => :id}.merge(belongs_to_options)

        opts[:key] = opts.delete(:source_key)
        opts[:primary_key] = opts.delete(:fk) if opts.has_key?(:fk)

        if (opts.delete(:type) == :array)
          opts[:type] = :array_to_many
        else
          opts[:type] = :many_to_one
        end

        self.associations[name] = opts


        define_belongs_to(name, opts)
      else
        raise "Calling Model.belongs to fetch association information is no longer supported. Use Model.associations instead."
      end
    end


    # Define one_to_many (aka: has_many)
    def self.one_to_many(name, &block)
      self.associations[name] = ConfigHash.from(type: :one_to_many, &block)
    end


    # Define many_to_one (aka: belongs_to)
    def self.many_to_one(name, &block)
      self.associations[name] = ConfigHash.from(type: :many_to_one, &block)
    end

    # Define array_to_many (aka: belongs_to where the key attribute is an array)
    def self.array_to_many(name, &block)
      self.associations[name] = ConfigHash.from(type: :array_to_many, &block)
    end

    # Define many_to_array (aka: has_many where the key attribute is an array)
    def self.many_to_array(name, &block)
      self.associations[name] = ConfigHash.from(type: :many_to_array, &block)
    end


    # Adds given identity to the list of model identities.
    # May be an array for composite keys.
    def self.identity(name)
      @_identities ||= Array.new
      @_identities << name
      self.config[:identities] << name
    end


    # Implements Praxis::Mapper DSL directive 'identities'.
    # Gets or sets list of identity fields.
    #
    # @param *names [Array] list of identity fields to set
    # @return [Array] configured list of identity fields
    # @example identities :id, :type
    def self.identities(*names)
      if names.any?
        self.config[:identities] = names
        @_identities = names
      else
        self.config.fetch(:identities)
      end
    end


    # Implements Praxis::Mapper DSL directive 'yaml'.
    # This will perform YAML.load on serialized data.
    #
    # @param name [String] name of field that is serialized as YAML
    # @param opts [Hash]
    # @options :default [String] default value?
    #
    # @example yaml :parent_ids, :default => []
    def self.yaml(name, opts={})
      @serialized_fields[name] = :yaml
      define_serialized_accessor(name, YAML, opts)
    end


    # Implements Praxis::Mapper DSL directive 'json'.
    # This will perform JSON.load on serialized data.
    #
    # @param name [String] name of field that is serialized as JSON
    # @param opts [Hash]
    # @options :default [String] default value?
    #
    # @example yaml :parent_ids, :default => []
    def self.json(name, opts={})
      @serialized_fields[name] = :json
      define_serialized_accessor(name, JSON, opts)
    end

    def self.define_serialized_accessor(name, serializer, **opts)
      define_method(name) do
        @deserialized_data[name] ||= if (value = @data.fetch(name))
          serializer.load(value)
        else
          opts[:default]
        end
      end

      define_method("_raw_#{name}".to_sym) do
        @data.fetch name
      end
    end

    def self.context(name, &block)
      default = Hash.new do |hash, key|
        hash[key] = Array.new
      end
      @contexts[name] = ConfigHash.from(default, &block).to_hash
    end


    def self.define_data_accessors(*names)
      names.each do |name|
        self.define_data_accessor(name)
      end
    end


    def self.define_data_accessor(name)
      module_eval <<-RUBY, __FILE__, __LINE__ + 1
        def #{name}
          @__#{name} ||= @data.fetch(#{name.inspect}) do
            raise "field #{name.inspect} not loaded for #{self.inspect}."
          end.freeze
        end
      RUBY
    end

    def self.define_associations
      self.associations.each do |name, association|
        self.define_association(name,association)
      end
    end

    def self.define_association(name, association)
      case association[:type]
      when :many_to_one
        self.define_many_to_one(name, association)
      when :array_to_many
        self.define_array_to_many(name, association)
      when :one_to_many
        self.define_one_to_many(name, association)
      when :many_to_array
        self.define_many_to_array(name, association)
      end
    end

    # has_many
    def self.define_one_to_many(name, association)
      model = association[:model]
      primary_key = association.fetch(:primary_key, :id)
      
      if primary_key.kind_of?(Array)
        define_method(name) do 
          pk = primary_key.collect { |k| self.send(k) }
          self.identity_map.all(model,association[:key] => [pk])
        end
      else
        define_method(name) do
          pk = self.send(primary_key)
          self.identity_map.all(model,association[:key] => [pk])
        end
      end
    end

    def self.define_many_to_one(name, association)
      model = association[:model]
      primary_key = association.fetch(:primary_key, :id)

      if association[:key].kind_of?(Array)
        key = "["
        key += association[:key].collect { |k| "self.#{k}" }.join(", ")
        key += "]"
      else
        key = "self.#{association[:key]}"
      end

      module_eval <<-RUBY, __FILE__, __LINE__ + 1
        def #{name}
          return nil if #{key}.nil?
          @__#{name} ||= self.identity_map.get(#{model.name},#{primary_key.inspect} => #{key})
        end
      RUBY

    end


    def self.define_array_to_many(name, association)
      model = association[:model]
      primary_key = association.fetch(:primary_key, :id)
      key = association.fetch(:key)
      
      module_eval <<-RUBY, __FILE__, __LINE__ + 1
       def #{name}
          return nil if #{key}.nil?
          @__#{name} ||= self.identity_map.all(#{model.name},#{primary_key.inspect} => #{key})
        end
      RUBY

    end


    def self.define_many_to_array(name, association)
      model = association[:model]
      primary_key = association.fetch(:primary_key, :id)
      key_name = association.fetch(:key)

      if primary_key.kind_of?(Array)
        key = "["
        key += primary_key.collect { |k| "self.#{k}" }.join(", ")
        key += "]"
      else
        key = "self.#{primary_key}"
      end

      module_eval <<-RUBY, __FILE__, __LINE__ + 1
        def #{name}
          key = #{key}
          return nil if key.nil?
          @__#{name} ||= self.identity_map.all(#{model.name}).
            select { |record| record.#{key_name}.include? key }
        end
      RUBY
    end



    # The belongs_to association creates a one-to-one match with another model.
    # In database terms, this association says that this class contains the foreign key.
    #
    # @param name [Symbol] name of association; typically the same as associated model name
    # @param opts [Hash] association options
    # @option :model [Model] the associated model
    # @option :fk [String] associated field name
    # @option :source_key [String] local field name
    # @option :type [Symbol] type of mapping, :scalar or :array
    #
    # @example
    #     define_belongs_to(:customer, {:model => Customer, :fk => :id, :source_key => :customer_id, :type => scalar})
    #
    # @see http://guides.rubyonrails.org/v2.3.11/association_basics.html#belongs-to-association-reference
    def self.define_belongs_to(name, opts)
      model = opts.fetch(:model)
      type = opts.fetch(:type, :many_to_one) # :scalar has no meaning other than it's not an array

      case opts.fetch(:type, :many_to_one)      
      when :many_to_one
        return self.define_many_to_one(name, opts)
      when :array_to_many
        return self.define_array_to_many(name, opts)
      end
    end


    # Looks up in the identity map first.
    #
    # @param condition ?
    # @return [Model] matching record
    def self.get(condition)
      IdentityMap.current.get(self, condition)
    end


    # Looks up in the identity map first.
    #
    # @param condition [Hash] ?
    # @return [Array<Model>] all matching records
    def self.all(condition={})
      IdentityMap.current.all(self, condition)
    end


    def initialize(data)
      @data = data
      @deserialized_data = {}
      @query = nil
    end

    InspectedFields = [:@data, :@deserialized_data].freeze
    def inspect
    "#<#{self.class}:0x#{object_id.to_s(16)} #{
          instance_variables.select{|v| InspectedFields.include? v}.map {|var|
            "#{var}: #{instance_variable_get(var).inspect}"
          }.join("#{'  '}")
        }#{'  '}>"
    end
      
    def respond_to_missing?(name, *)
      @data.key?(name) || super
    end


    def method_missing(name, *args)
      if @data.has_key? name
        self.class.define_data_accessor(name)
        self.send(name)
      else
        super
      end
    end


    def identities
      self.class._identities.each_with_object(Hash.new) do |identity, hash|
        case identity
        when Symbol
          hash[identity] = @data[identity].freeze
        else
          hash[identity] = @data.values_at(*identity).collect(&:freeze)
        end
      end
    end

    def _data
      @data
    end

  end

end
