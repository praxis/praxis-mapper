# In-memory query designed for use with the MemoryRepository for specs

module Praxis::Mapper
  module Support
    class MemoryQuery < Praxis::Mapper::Query::Base

      def collection
        connection.collection(model.table_name)
      end

      def _multi_get(key, values)
        results = values.collect do |value|
          connection.all(model, key =>  value)
        end.flatten.uniq

        results.select do |result|
          where.nil? || where.all? do |k,v|
            result[k] == v
          end
        end
      end

      def _execute
        connection.all(model.table_name, self.where||{}).to_a
      end

      # Subclasses Must Implement
      def describe
        raise "subclass responsibility"
      end

    end
  end
end
