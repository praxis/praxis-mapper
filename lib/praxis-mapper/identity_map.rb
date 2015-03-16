# An identity map that tracks data that's been loaded, and data that we still need to load.
# As tables are loaded and processed, the identity map will keep a list of child models that have been "seen" and will need to be loaded for the final view.
# The identity map defines a scope for the associated queries.
# The scope can be thought of as a set of named filters.
module Praxis::Mapper
  class IdentityMap

    class UnloadedRecordException < StandardError; end;
    class UnsupportedModel < StandardError; end;
    class UnknownIdentity < StandardError; end;

    attr_reader :unloaded, :queries, :blueprint_cache
    attr_accessor :scope

    class << self
      attr_accessor :config
    end


    # Stores given identity map in a thread-local variable
    # @param [IdentityMap] some identity map
    def self.current=(identity_map)
      Thread.current[:_praxis_mapper_identity_map] = identity_map
    end


    # @return [IdentityMap] current identity map from thread-local variable
    def self.current
      map = Thread.current[:_praxis_mapper_identity_map]
      raise "current IdentityMap not set" unless map
      map
    end


    # @return [Boolean] whether identity map thread-local variable has been set
    def self.current?
      Thread.current.key?(:_praxis_mapper_identity_map) && Thread.current[:_praxis_mapper_identity_map].kind_of?(Praxis::Mapper::IdentityMap)
    end


    def clear?
      @rows.empty? &&
        @staged.empty? &&
        @row_keys.empty? &&
        @queries.empty?
    end


    # TODO: how come scope can be set from 3 different methods?
    #
    # @param scope [Hash] a set of named filters to apply in query
    # @example {:account => [:account_id, 71], :user => [:user_id, 2]}
    #
    def self.setup!(scope={})
      if self.current?
        if !self.current.clear?
          raise "Denied for a pre-existing condition: Identity map has been used."
        else
          self.current.scope = scope
          return self.current
        end
      else
        self.current = self.new(scope)
      end
    end

    # TODO: support multiple connections
    def initialize(scope={})
      @connection_manager = ConnectionManager.new
      @scope = scope
      clear!
    end

    def clear!
      @rows = Hash.new { |h,k| h[k] = Array.new }

      # for ex:
      #   @staged[Instance][:id] = Set.new
      # yields:
      #  {Instance => {:id => Set.new(1,2,3), :name => Set.new("George Jr.") } }
      @staged = Hash.new do |hash,model|
        hash[model] = Hash.new do |identity_hash, identity_name|
          identity_hash[identity_name] = Set.new
        end
      end

      # for ex:
      #   @row_keys["instances"][:id][1] = Object.new
      # yields:
      #   {"instances"=>{:id=>{1=>Object.new}}
      @row_keys = Hash.new do |row_hash,model|
        row_hash[model] = Hash.new do |primary_keys, key_name|
          primary_keys[key_name] = Hash.new
        end
      end

      @queries = Hash.new { |h,k| h[k] = Set.new }

      # see how it feels to store blueprints here
      # for ex:
      #   @blueprints[User][some_object] = User.new(some_object)
      @blueprint_cache = Hash.new do |cache,blueprint_class|
        cache[blueprint_class] = Hash.new
      end

      # TODO: rework this so it's a hash with default values and simplify #index
      @secondary_indexes =  Hash.new
    end


    def load(model, &block)
      raise "Can't load unfinalized model #{model}" unless model.finalized?

      query_class = @connection_manager.repository(model.repository_name)[:query]
      query = query_class.new(self, model, &block)

      if query.where == :staged
        query.where = nil
        return finalize_model!(model, query)
      end

      records = query.execute
      actually_added = add_records(records)

      # TODO: refactor this to better-hide queries?
      query.freeze
      self.queries[model].add(query)

      subload(model, query,records)

      actually_added
    end

    def stage_for!(spec, records)
      case spec[:type]
      when :many_to_one
        stage_many_to_one(spec, records)
      when :array_to_many
        stage_array_to_many(spec, records)
      when :one_to_many
        stage_one_to_many(spec, records)
      when :many_to_array
        stage_many_to_array(spec, records)
      end
    end

    def subload(model, query, records)
      query.load.each do |(association_name, block)|
        spec = model.associations.fetch(association_name)

        associated_model = spec[:model]

        key, values = stage_for!(spec, records)

        existing_records = []
        values.reject! do |value|
          if @row_keys[associated_model].has_key?(key) &&
              @row_keys[associated_model][key].has_key?(value)
            existing_records << @row_keys[associated_model][key][value]
          else
            false
          end
        end

        new_query_class = @connection_manager.repository(associated_model.repository_name)[:query]
        new_query = new_query_class.new(self,associated_model, &block)

        new_records = new_query.multi_get(key, values)

        self.queries[associated_model].add(new_query)

        add_records(new_records)

        subload(associated_model, new_query, new_records + existing_records)
      end
    end

    def finalize!(*models)
      if models.empty?
        models = @staged.keys
      end

      did_something = models.any? do |model|
        finalize_model!(model).any?
      end

      finalize! if did_something
    end


    # don't doc. never ever use yourself!
    # FIXME: make private and fix specs that break?
    def finalize_model!(model, query=nil)
      staged_queries = @staged[model].delete(:_queries) || []
      staged_keys = @staged[model].keys
      identities = staged_keys && model.identities
      non_identities = staged_keys - model.identities

      results = Set.new

      return results if @staged[model].all? { |(key,values)| values.empty? }

      if query.nil?
        query_class = @connection_manager.repository(model.repository_name)[:query]
        query = query_class.new(self,model)
      end

      # Apply any relevant blocks passed to track in the original queries
      staged_queries.each do |staged_query|
        staged_query.track.each do |(association_name, block)|
          next unless block

          spec = staged_query.model.associations[association_name]

          if spec[:model] == model
            query.instance_eval(&block)
            if (spec[:type] == :many_to_one || spec[:type] == :array_to_many) && query.where
              file, line = block.source_location
              trace = ["#{file}:#{line}"] | caller
              raise RuntimeError, "Error finalizing model #{model.name} for association #{association_name.inspect} -- using a where clause when tracking associations of type #{spec[:type].inspect} is not supported", trace
            end
          end
        end
      end


      # process non-unique staged keys
      #   select identity (any one should do) for those keys and stage blindly
      #   load and add records.

      if non_identities.any?
        to_stage = Hash.new do |hash,identity|
          hash[identity] = Set.new
        end

        non_identities.each do |key|
          values = @staged[model].delete(key)

          rows = query.multi_get(key, values, select: model.identities, raw: true)
          rows.each do |row|
            model.identities.each do |identity|
              if identity.kind_of? Array
                to_stage[identity] << row.values_at(*identity)
              else
                to_stage[identity] << row[identity]
              end
            end
          end
        end

        self.stage(model, to_stage)
      end

      model.identities.each do |identity_name|
        values = self.get_staged(model,identity_name)
        next if values.empty?

        query.where = nil # clear out any where clause from non-identity
        records = query.multi_get(identity_name, values)

        # TODO: refactor this to better-hide queries?
        self.queries[model].add(query)

        results.merge(add_records(records))

        # add nil records for records that were not found by the multi_get
        missing_keys = self.get_staged(model,identity_name)
        missing_keys.each do |missing_key|
          @row_keys[model][identity_name][missing_key] = nil
          get_staged(model, identity_name).delete(missing_key)
        end

      end

      query.freeze

      # TODO: check whether really really did get all the records we should have....
      results.to_a
    end


    def row_by_key(model,key, value)
      @row_keys[model][key].fetch(value) do
        raise UnloadedRecordException, "Did not load #{model} with #{key} = #{value.inspect}."
      end

    end


    def rows_for(model)
      @rows[model]
    end


    def index(model, key, value)
      @secondary_indexes[model] ||= Hash.new

      unless @secondary_indexes[model].has_key? key
        @secondary_indexes[model][key] ||= Hash.new
        reindex!(model, key)
      end

      @secondary_indexes[model][key][value] ||= Array.new
    end


    def reindex!(model, key)
      rows_for(model).each do |row|
        val = if key.kind_of? Array
          key.collect { |k| row.send(k) }
        else
          row.send(key)
        end
        index(model, key, val) << row
      end
    end


    def all(model,conditions={})
      return rows_for(model) if conditions.empty?

      key, values = conditions.first

      # optimize the common case of a single value
      if values.size == 1
        value = values[0]
        if @row_keys[model].has_key?(key)
          res = row_by_key(model, key, value)
          if res
            [res]
          else
            []
          end
        else
          index(model, key, value)
        end
      else
        if @row_keys[model].has_key?(key)
          values.collect do |value|
            row_by_key(model, key, value)
          end.compact
        else
          values.each_with_object(Array.new) do |value, results|
            results.push *index(model, key, value)
          end
        end
      end
    end


    def get(model,condition)
      key, value = condition.first

      row_by_key(model, key, value)
    end


    def get_staged(model, key)
      @staged[model][key]
    end


    def stage(model, data)
      data.each do |key, values|
        unless values.kind_of? Enumerable
          values = [values]
        end

        # ignore rows we have already loaded... add sanity checking?
        if model.identities.include?(key)
          values.reject! { |k| @row_keys[model][key].has_key? k }
        end

        get_staged(model,key).merge(values)
      end
    end


    def connection(name)
      @connection_manager.checkout(name)
    end

    def extract_keys(field, records)
      row_keys = []
      if field.kind_of?(Array) # composite identities
        records.each do |record|
          row_key = field.collect { |col| record.send(col) }
          row_keys << row_key unless row_key.include?(nil)
        end
      else
        row_keys.push *records.collect(&field).compact
      end
      row_keys
    end


    def stage_many_to_one(tracked_association, records)
      key = tracked_association[:key]
      primary_key = tracked_association[:primary_key] || :id

      row_keys = extract_keys(key, records)

      [primary_key, row_keys]
    end


    def stage_one_to_many(tracked_association, records)
      key = tracked_association[:key]
      primary_key = tracked_association[:primary_key] || :id

      row_keys = extract_keys(primary_key, records)

      [key, row_keys]
    end


    def stage_array_to_many(tracked_association, records)
      key = tracked_association[:key]
      primary_key = tracked_association[:primary_key] || :id

      row_keys = []
      records.collect(&key).each do |keys|
        row_keys.push *keys
      end

      row_keys.reject! do |row_key|
        row_key.nil? || (row_key.kind_of?(Array) && row_key.include?(nil))
      end

      [primary_key, row_keys]
    end



    def stage_many_to_array(tracked_association, records)
      raise "not supported yet"
    end


    def add_records(records)
      records_added = Array.new
      return records_added if records.empty? 

      to_stage = Hash.new do |hash,staged_model|
        hash[staged_model] = Hash.new do |identities, identity_name|
          identities[identity_name] = Set.new
        end
      end

      model = records.first.class

      tracked_associations = if (query = records.first._query)
        query.tracked_associations.each do |tracked_association|
          associated_model = tracked_association[:model]
          to_stage[associated_model][:_queries] << query
        end
      else
        []
      end

      tracked_associations.each do |tracked_association|
        associated_model = tracked_association[:model]
        association_type = tracked_association[:type]

        association_key, row_keys = stage_for!(tracked_association, records)
        row_keys.each do |row_key|
          to_stage[associated_model][association_key].add(row_key)
        end

      end

      records_added = records.collect do |record|
        add_record(record)
      end

      to_stage.each do |model_to_stage, data|
        stage(model_to_stage, data)
      end

      records_added
    end


    # return the record provided (if added to the identity map)
    # or return the corresponding record if it was already present
    def add_record(record)
      model = record.class
      record.identities.each do |identity, key|
        # FIXME: Should we be overwriting (possibly) a "nil" value from before?
        #        (due to that row not being found by a previous query)
        #        (That'd be odd since that means we tried to load that same identity)
        if (existing = @row_keys[model][identity][key])
          # FIXME: should merge record into existing to add any additional fields
          return existing
        end

        get_staged(model, identity).delete(key)
        @row_keys[model][identity][key] = record
      end

      record.identity_map = self
      @rows[model] << record
      record
    end

    alias_method :<<, :add_record

    def query_statistics
      QueryStatistics.new(queries)
    end

  end
end
