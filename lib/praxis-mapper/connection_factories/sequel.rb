module Praxis::Mapper
  module ConnectionFactories

    class Sequel

      def initialize(connection:nil, **opts)
        raise ArgumentError, 'May not provide both a connection and opts' if connection && !opts.empty?

        if connection
          @connection = connection
        else
          @connection = ::Sequel.connect(**opts)
        end

        @timeout = @connection.pool.instance_variable_get(:@timeout)
        @sleep_time = @connection.pool.instance_variable_get(:@sleep_time)

        # connections that we created explicitly
        @owned_connections = Hash.new
      end

      def checkout(connection_manager)
        unless acquire(connection_manager.thread)
          time = Time.now
          timeout = time + @timeout
          sleep_time = @sleep_time
          sleep sleep_time
          until acquire(connection_manager.thread)
            raise(::Sequel::PoolTimeout) if Time.now > timeout
            sleep sleep_time
          end
        end

        @connection
      end

      def release(connection_manager, connection)
        if (@owned_connections.delete(connection_manager.thread))
          @connection.pool.send(:sync) do
            @connection.pool.send(:release,connection_manager.thread)
          end
        end
      end

      def acquire(thread)
        if (owned = @connection.pool.send(:owned_connection, thread))
          return true
        else
          conn = @connection.pool.send(:acquire, thread)
          @owned_connections[thread] = conn
          true
        end
      end

    end
  end
end
