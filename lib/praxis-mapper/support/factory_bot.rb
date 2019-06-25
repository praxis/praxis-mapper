# Hackish write support for Praxis::Mapper, needed for FactoryBot.create calls.
# TODO: get rid of this and use current FactoryBot features to do it the right way.

module Praxis::Mapper
  class Model

    def save!
      @new_record = true
      unless Praxis::Mapper::IdentityMap.current.add_records([self]).include? self
        raise "Conflict trying to save record with type: #{self.class} and data:\n#{@data.pretty_inspect}"
      end
    end

    alias_method :original_method_missing, :method_missing

    def method_missing(name, *args)
      if name.to_s =~ /=$/
        name = name.to_s.sub!("=", "").to_sym
        value = args.first

        if self.class.associations.has_key?(name)
          set_association(name, value)
        elsif self.class.serialized_fields.has_key?(name)
          set_serialized_field(name, value)
        else
          if value.kind_of?(Praxis::Mapper::Model)
            raise "Can not set #{self.class.name}##{name} with Model instance. Are you missing an association?"
          end
          @data[name] = value
        end
      else
        original_method_missing(name, *args)
      end
    end


    def set_serialized_field(name,value)
      @deserialized_data[name] = value

      case self.class.serialized_fields[name]
      when :json
        @data[name] = JSON.dump(value)
      when :yaml
        @data[name] = YAML.dump(value)
      else
        @data[name] = value # dunno
      end
    end

    def set_association(name, value)
      spec = self.class.associations.fetch(name)

      case spec[:type]
      when :one_to_many
        raise "can not set one_to_many associations to nil" if value.nil?
        primary_key = @data[spec[:primary_key]]
        setter_name = "#{spec[:key]}="
        Array(value).each { |item| item.send(setter_name, primary_key) }
      when :many_to_one
        primary_key = value && value.send(spec[:primary_key])
        @data[spec[:key]] = primary_key
      else
        raise "can not handle associations of type #{spec[:type]}"
      end

    end


    def initialize(data={})
      @data = data
      @deserialized_data = {}
      @new_record = false
    end

    attr_accessor :new_record

  end

  class IdentityMap

    def persist!
      @rows.each_with_object(Hash.new) do |(model, records), inserted|
        next unless (table = model.table_name)

        db ||= self.connection(model.repository_name)

        new_records = records.select(&:new_record)
        next if new_records.empty?
        
        db[table.to_sym].multi_insert new_records.collect(&:_data)

        new_records.each { |rec| rec.new_record = false }
        inserted[model] = new_records        
      end
    end


  end

end
