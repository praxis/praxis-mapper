module Praxis::Mapper
  class ConnectionManager

    # Configures a data store.
    def self.setup(config_data={}, &block)
      config_data.each do |repository_name, data|
        klass_name = data.delete(:connection_factory)
        connection_factory_class = Object.const_get(klass_name)
        repositories[repository_name][:connection_factory] = connection_factory_class.new(data[:connection_opts])

        if (query_klass_name = data.delete(:query))
          query_klass = Object.const_get(query_klass_name)
          repositories[repository_name][:query] = query_klass
        end
      end
      if block_given?
        self.instance_eval(&block)
      end
    end

    def self.repository(repository_name, data=nil,&block)
      return repositories[repository_name] if data.nil? && !block_given?

      if data && data[:query]
        query_klass = case data[:query]
        when String
          query_klass_name = data[:query]
          Object.const_get(query_klass_name) #FIXME: won't really work consistently
        when Class
          data[:query]
        when Symbol
          raise "symbol support is not implemented yet"
        else
          raise "unknown type for query: #{data[:query].inspect} has type #{data[:query].class}"
        end
        repositories[repository_name][:query] = query_klass
      end
      
      if block_given?
        # TODO: ? complain if data.has_key?(:connection_factory)
        repositories[repository_name][:connection_factory] = block
      elsif data
        klass_name = data.delete(:connection_factory)
        connection_factory_class = Object.const_get(klass_name) #FIXME: won't really work consistently
        repositories[repository_name][:connection_factory] = connection_factory_class.new(data[:connection_opts])
      end
    end


    def self.repositories
      @repositories ||= Hash.new do |hash,key|
        hash[key] = {
          :connection_factory => nil,
          :query => Praxis::Mapper::Query::Sql
        }
      end
    end

    def repositories
      self.class.repositories
    end

    def repository(repository_name)
      self.repositories[repository_name]
    end

    def initialize
      @connections = {}
    end

    def checkout(name)
      connection = @connections[name]
      return connection if connection

      factory = repositories[name][:connection_factory]
      connection = if factory.kind_of?(Proc)
        factory.call
      else
        factory.checkout
      end

      @connections[name] = connection
    end

    def release_one(name)
      if (connection = @connections.delete(name))
        return true if repositories[name][:connection_factory].kind_of? Proc
        repositories[name][:connection_factory].release(connection)
      end
    end

    def release(name=nil)
      if name
        release_one(name)
      else
        names = @connections.keys
        names.each { |name| release_one(name) }
      end
    end

  end
end
