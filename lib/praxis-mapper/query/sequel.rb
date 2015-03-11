require "set"

module Praxis::Mapper
  module Query

    # Sequel-centric query class
    class Sequel < Base


      def initialize(identity_map, model, &block)
        super
      end

      def dataset
        ds = connection[model.table_name.to_sym]

        # TODO: support column aliases
        if @select
          ds = ds.select(*@select.keys)
        end

        if @where
          ds = ds.where(@where)
        end

        if @limit
          ds = ds.limit(@limit)
        end

        ds
      end

      # Executes a 'SELECT' statement.
      #
      # @param identity [Symbol|Array] a simple or composite key for this model
      # @param values [Array] list of identifier values (ideally a sorted set)
      # @return [Array] SQL result set
      #
      # @example numeric key
      #     _multi_get(:id, [1, 2])
      # @example string key
      #     _multi_get(:uid, ['foo', 'bar'])
      # @example composite key (possibly a combination of numeric and string keys)
      #     _multi_get([:cloud_id, :account_id], [['foo1', 'bar1'], ['foo2', 'bar2']])
      def _multi_get(identity, values)
        ds = self.dataset.where(identity => values)
        _execute(ds)
      end

      # Executes this SQL statement.
      # Does not perform any validation of the statement before execution.
      #
      # @return [Array] result-set
      def _execute(ds=nil)
        Praxis::Mapper.logger.debug "SQL:\n#{self.describe}\n"
        self.statistics[:datastore_interactions] += 1
        start_time = Time.now

        rows = if @raw_query
          unless ds.nil?
            warn 'WARNING: Query::Sequel#_execute ignoring passed dataset due to previously-specified raw SQL'
          end
          connection.run(@raw_query).to_a
        else
          (ds || self.dataset).to_a
        end

        self.statistics[:datastore_interaction_time] += (Time.now - start_time)
        return rows
      end

      # @see #sql
      def describe
        self.sql
      end

      # Constructs a raw SQL statement.
      # No validation is performed here (security risk?).
      #
      # @param sql_text a custom SQL query
      #
      def raw(sql_text)
        @raw_query = sql_text
      end

      # @return [String] raw or assembled SQL statement
      def sql
        if @raw_query
          @raw_query
        else
          dataset.sql
        end
      end


    end

  end

end
