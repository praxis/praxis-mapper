require 'active_support/concern'

module Praxis::Mapper
  module SequelCompat
    extend ActiveSupport::Concern

    included do
      attr_accessor :_resource
      attr_accessor :_query
      attr_accessor :identity_map

      @repository_name = :default
    end

    module ClassMethods

      def identities
        [primary_key]
      end

      def finalized?
        true
      end

      def associations
        orig = self.association_reflections.clone

        orig.each do |k,v|
          v[:model] = v.associated_class
          v[:primary_key] = v.primary_key
        end
        orig
      end

      def repository_name(name=nil)
        return @repository_name if name.nil?

        @repository_name = name
      end

    end


    def _load_associated_objects(opts, dynamic_opts=OPTS)
      return super if self.identity_map.nil?
      target = opts.associated_class
      key = opts[:key]

      case opts[:type]
      when :many_to_one
        val = if key.kind_of?(Array)
          @values.values_at(*key)
        else
          @values[key]
        end
        return nil if val.nil?
        self.identity_map.get(target, target.primary_key => val)
      when :one_to_many
        self.identity_map.all(target, key => [pk] )
      when :many_to_many
        # OPTIMIZE: cache this result
        join_model = opts[:join_model].constantize

        left_key = opts[:left_key]
        right_key = opts[:right_key]

        right_values = self.identity_map.
          all(join_model, left_key => Array(values[primary_key])).
          collect(&right_key)

        self.identity_map.all(target, target.primary_key => right_values )
      else
        raise "#{opts[:type]} is not currently supported"
      end
    end


    def identities
      self.class.identities.each_with_object(Hash.new) do |identity, hash|
        case identity
        when Symbol
          hash[identity] = values[identity].freeze
        else
          hash[identity] = values.values_at(*identity).collect(&:freeze)
        end
      end
    end


  end
end
