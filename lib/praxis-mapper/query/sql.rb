require "set"

module Praxis::Mapper
  module Query

    # An SQL 'SELECT' statement assembler.
    # Assumes ISO SQL:2008 unless otherwise noted.
    # TODO: rename to MySql or MySql5 or MySql51 or something
    #
    # The SQL SELECT statement returns a result set of records from one or more tables.
    #
    # The SELECT statement has two mandatory clauses:
    # - SELECT specifies which columns/aliases to return.
    # - FROM specifies which tables/views to query.
    #
    # The SELECT statement has many optional clauses:
    # - WHERE specifies which rows to retrieve.
    # - GROUP BY groups rows sharing a property so that an aggregate function can be applied to each group.
    # - HAVING selects among the groups defined by the GROUP BY clause.
    # - ORDER BY specifies an order in which to return the rows.
    # - LIMIT specifies how many rows to return (non-standard).
    #
    # Currently only SELECT, FROM, WHERE and LIMIT has been implemented.
    #
    # @example "SELECT column1, column2 FROM table1 WHERE column1=value1 AND column2=value2"
    #
    # @see http://en.wikipedia.org/wiki/Select_(SQL)
    class Sql < Base

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
        dataset = connection[model.table_name.to_sym].where(identity => values)

        # MySQL 5.1 won't use an index for a multi-column IN clause. Consequently, when adding
        # multi-column IN clauses, we also add a single-column IN clause for the first column of
        # the multi-column IN-clause. In this way, MySQL will be able to use an index for the
        # single-column IN clause but will use the multi-column IN clauses to limit which
        # records are returned.
        if identity.kind_of?(Array)
          dataset = dataset.where(identity.first => values.collect(&:first))
        end

        # preserve existing where condition from query
        if @where
          dataset = dataset.where(@where)
        end

        clause = dataset.literal(dataset.opts[:where])

        original_where = @where

        self.where clause
        _execute
      ensure
        @where = original_where
      end

      # Executes this SQL statement.
      # Does not perform any validation of the statement before execution.
      #
      # @return [Array] result-set
      def _execute
        Praxis::Mapper.logger.debug "SQL:\n#{self.describe}\n"
        self.statistics[:datastore_interactions] += 1
        start_time = Time.now

        if @where && @raw_query
          warn 'WARNING: Query::Sql#_execute ignoring requested `where` clause due to specified raw SQL'
        end
        rows = connection.fetch(self.sql).to_a

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
          [select_clause, from_clause, where_clause, limit_clause].compact.join("\n")
        end
      end

      # @return [String] SQL 'SELECT' clause
      def select_clause
        columns = []
        if select && select != true
          select.each do |alias_name, column_name|
            if column_name
              # alias_name is always a String, not a Symbol
              columns << "#{column_name} AS #{alias_name}"
            else
              columns << (alias_name.is_a?(Symbol) ? alias_name.to_s : alias_name)
            end
          end
        else
          columns << '*'
        end

        "SELECT #{columns.join(', ')}"
      end

      # @return [String] SQL 'FROM' clause
      #
      # FIXME: use ANSI SQL double quotes instead of MySQL backticks
      # @see http://stackoverflow.com/questions/261455/using-backticks-around-field-names
      def from_clause
        "FROM `#{model.table_name}`"
      end

      # @return [String] SQL 'LIMIT' clause or nil
      #
      # NOTE: implementation-dependent; not part of ANSI SQL
      # TODO: replace with ISO SQL:2008 FETCH FIRST clause
      def limit_clause
        if self.limit
          return "LIMIT #{self.limit}"
        end
      end

      # Constructs the 'WHERE' clause with all active scopes (read: named conditions).
      #
      # @return [String] an SQL 'WHERE' clause or nil if no conditions
      #
      # FIXME: use ANSI SQL double quotes instead of MySQL backticks
      # FIXME: Doesn't sanitize any values. Could be "fun" later (where fun means a horrible security hole)
      # TODO: add per-model scopes, ie, servers might have a scope for type = "GenericServer"
      def where_clause
        # collects and compacts conditions as defined in identity map and model
        conditions = identity_map.scope.collect do |name, condition|
          # checks if this condition has been banned for this model
          unless model.excluded_scopes.include? name
            column, value = condition # example: "user_id", 123
            case value
            when Integer
              "`#{column}`=#{value}"
            when String
              "`#{column}`='#{value}'"
            when NilClass
              "`#{column}` IS NULL"
            else
              raise "unknown type for scope #{name} with condition #{condition}"
            end
          end
        end.compact

        conditions << where if where

        if conditions.any?
          return "WHERE #{conditions.join(" AND ")}"
        else
          nil
        end
      end

    end

  end

end
