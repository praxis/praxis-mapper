module Praxis::Mapper
  class ConnectionManager

    @repositories = {}
    class << self
      attr_accessor :repositories
    end

    def self.setup(&block)
      if block_given?
        self.instance_eval(&block)
      end
    end

    def self.repository(repository_name, **data, &block)
      return repositories[repository_name] if data.empty? && !block_given?

      query = data[:query] || Praxis::Mapper::Query::Sql
      factory_class = data[:factory] || ConnectionFactories::Simple
      
      opts = data[:opts] || {}
      if query.kind_of? String
        query = query.constantize
      end

      if factory_class.kind_of? String
        factory_class = factory_class.constantize
      end
      
      repositories[repository_name] = {
        query: query,
        factory: factory_class.new(**opts, &block)
      }
    end

    
    def repositories
      self.class.repositories
    end

    def repository(repository_name)
      self.repositories[repository_name]
    end

    def initialize
      @connections = {}
      @thread = Thread.current
    end

    def thread
      return @thread if @thread == Thread.current
      raise 'threading violation in ConnectionManager. Calling Thread is different from Thread that owns this instance.'
    end

    def checkout(name)
      connection = @connections[name]
      return connection if connection

      factory = repositories[name][:factory]
      connection = factory.checkout(self)

      @connections[name] = connection
    end

    def release_one(name)
      if (connection = @connections.delete(name))
        repositories[name][:factory].release(self, connection)
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
