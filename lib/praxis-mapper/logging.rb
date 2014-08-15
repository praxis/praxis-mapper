module Praxis::Mapper

  class NullLogger

    # do nothing!
    def initialize(*args)
    end

    def method_missing(*args, &block)
    end

  end

  def self.logger
    @@logger ||= NullLogger.new
  end

  def self.logger=(logger)
    @@logger = logger
  end
  
end