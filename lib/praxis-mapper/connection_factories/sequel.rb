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

        # steal timeout values so we can replicate the same timeout behavior
        @timeout = @connection.pool.instance_variable_get(:@timeout)
        @sleep_time = @connection.pool.instance_variable_get(:@sleep_time)

        # connections that we created explicitly
        @owned_connections = Hash.new
      end

      def checkout(connection_manager)
        # copied from Sequel's ThreadedConnectionPool#hold
        # to ensure consistent behavior
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
        # ensure we only release connections we own, in case
        # we've acquired a connection from Sequel that
        # is likely still in use.
        if (@owned_connections.delete(connection_manager.thread))
          @connection.pool.send(:sync) do
            @connection.pool.send(:release,connection_manager.thread)
          end
        end
      end

      def acquire(thread)
        # check connection's pool to see if it already has a connection
        # if so, re-use it. otherwise, acquire a new one and mark that we
        # "own" it for future releasing.
        if @connection.pool.send(:owned_connection, thread)
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
