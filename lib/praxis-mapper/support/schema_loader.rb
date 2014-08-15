require 'pathname'

Sequel.extension :migration

module Praxis::Mapper
  module Support
    class SchemaLoader

      attr_reader :options, :schema_root

      def initialize(schema_root='.', **options)
        @schema_root = Pathname.new(schema_root)
        @options = options
        @connection_manager = ConnectionManager.new
        @repositories = Set.new

        @migrations = Hash.new

        @connection_manager.repositories.each do |repository_name, config|

          next unless config[:query] == Praxis::Mapper::Query::Sql

          migration_path = @schema_root + repository_name.to_s

          migration_path.children.each do |file|
            table = file.basename.to_s[0..-4]

            before = Sequel::Migration.descendants.clone
            require file.expand_path if file.exist?

            after = Sequel::Migration.descendants

            migration = (after - before).first

            @migrations[repository_name] ||= Array.new
            @migrations[repository_name] << [table, migration]
          end

        end
      end


      def load!
        @migrations.each do |repository_name, migrations|
          connection = @connection_manager.checkout(repository_name)

          migrations.each do |(table, migration)|
            migration.apply(connection, :up)
          end
        end
   
      end

    end
  end
end
