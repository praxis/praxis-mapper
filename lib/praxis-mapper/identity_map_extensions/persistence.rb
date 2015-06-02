module Praxis::Mapper
  module IdentityMapExtensions
    module Persistence

      def deindex(record)
        model = record.class

        # delete from full set of rows
        rows_for(model).delete record 

        # remove record from identity indexes
        @row_keys[model].each do |identity, index|
          index.delete_if {|k,v| v == record }
        end

        # remove any secondary indexes
        @secondary_indexes[model].each do |key, index|
          index.each do |index_key, indexed_values|
            indexed_values.delete record
          end
        end
      end

      def reindex(record)
        # fully remove the record from any indexes it may be part of
        deindex(record)

        # hack to update any indexes as applicable
        add_record(record)
      end

      # attach record to the identity map.
      # save the record if, and only if, we need to
      def attach(record)
        # save unless it has all identities populated
        unless record.identities.all? { |identity, value| value }
          record.save
        end

        # raise if still don't have full identities
        unless record.identities.all? { |identity, value| value }
          raise "can not attach #{record.inspect} without a full set of identities."
        end

        add_record(record)

        # TODO: what to do with related records?
      end

      def flush!(object=nil)
        if object.nil?
          return @rows.keys.each { |klass| self.flush!(klass) }
        end

        case object
        when Class
          @rows[object].select(&:modified?).each do |record|
            record.save
            reindex(record)
          end
        when Sequel::Model
          if object.modified?
            object.save
            reindex(object)
          end
        end
      end

      def remove(record)
        detach(record)

        record.delete
      end

      def detach(record)
        record.identity_map = nil
        deindex(record)
      end
    end


  end
end
