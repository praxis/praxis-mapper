module Praxis::Mapper
  module ConnectionFactories
    class Simple
      def initialize(connection: nil, &block)
        @connection = connection if connection
        if block
          @checkout = block
        end

        if @connection && @checkout
          raise ArgumentError, 'May not provide both a connection and block'
        end
      end

      def checkout(connection_manager)
        return @connection if @connection
        
        @checkout.call        
      end

      def release(connection_manager, connection)
        true
      end

    end
  end
end
