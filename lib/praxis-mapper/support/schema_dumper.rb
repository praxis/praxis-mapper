require 'fileutils'

module Praxis::Mapper
  module Support
    class SchemaDumper

      attr_reader :options, :repositories, :schema_root

      def initialize(schema_root='.', **options)
        @schema_root = Pathname.new(schema_root)

        @options = options
        @connection_manager = ConnectionManager.new

        @repositories = Hash.new do |hash, repository_name|
          hash[repository_name] = Set.new
        end

        setup!
      end

      def setup!
        @connection_manager.repositories.each do |repository_name, config|
          next unless config[:query] == Praxis::Mapper::Query::Sql

          models = Praxis::Mapper::Model.descendants.
            select { |model| model.repository_name == repository_name }.
            select { |model| model.table_name }

          models.each do |model|
            table = model.table_name
            repository = model.repository_name
            self.repositories[repository] << table
          end
        end
      end

      def dump_all!
        repositories.each do |repository_name, tables|
          self.dump!(repository_name)
        end
      end

      def dump!(repository_name)
        connection = @connection_manager.checkout(repository_name)
        connection.extension :schema_dumper

        tables = self.repositories.fetch repository_name

        FileUtils.mkdir_p(schema_root + repository_name.to_s)

        tables.each do |table|
          File.open(schema_root + repository_name.to_s + "#{table}.rb" ,"w+") do |file|
            file.puts "Sequel.migration do"
            file.puts "  up do"
            file.puts connection.dump_table_schema(table).gsub(/^/o, '    ')
            file.puts "\n"
            file.puts "  end"
            file.puts "end"
          end
        end
      end
    end

  end
end
