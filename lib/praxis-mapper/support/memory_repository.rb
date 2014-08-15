# Unoptimized, highly inefficient in-memory datastore designed for use with specs.

module Praxis::Mapper
  module Support
    class MemoryRepository

      attr_reader :collections

      def initialize
        clear!
      end

      def clear!
        @collections = Hash.new do |hash, collection_name|
          hash[collection_name] = Set.new
        end
      end

      def collection(collection)
        collection_name = if collection.respond_to?(:table_name)
          collection.table_name.to_sym
        else
          collection.to_sym
        end

        @collections[collection_name]
      end

      def insert(collection, *values)
        self.collection(collection).merge(*values)
      end

      # Retrieve all records for +collection+ matching all +conditions+.
      def all(collection, **conditions)
        self.collection(collection).select do |row|
          conditions.all? do |k,v|
            row[k] === v
          end
        end
      end

    end
  end
end
