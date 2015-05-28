require 'json'
require 'yaml'
require 'logger'

require 'sequel'

module Praxis
  module Mapper

    # Get the logger configured for Praxis::Mapper
    #
    # @example Basic usage
    #   Praxis::Mapper.logger.info 'Something interesting happened'
    #
    # @return [Logger] The currently configured logger or a STDOUT logger
    #
    def self.logger
      @logger ||= begin
        require 'logger'
        Logger.new(STDOUT)
      end
    end

    # Set the logger configured for Praxis::Mapper
    #
    # @example Basic usage
    #   Praxis::Mapper.logger = Logger.new('log/development.log')
    #
    # @return [Logger] The logger object
    #
    def self.logger=(logger)
      @logger = logger
    end


    # Perform any final initialiation needed
    def self.finalize!
      Praxis::Mapper::Model.finalize!
      Praxis::Mapper::Resource.finalize!
    end

  end
end

require 'praxis-mapper/finalizable'
require 'praxis-mapper/logging'

require 'praxis-mapper/identity_map_extensions/persistence'
require 'praxis-mapper/identity_map'

require 'praxis-mapper/model'
require 'praxis-mapper/query_statistics'

require 'praxis-mapper/sequel_compat' 

require 'praxis-mapper/connection_manager'

require 'praxis-mapper/connection_factories/simple'
require 'praxis-mapper/connection_factories/sequel'

require 'praxis-mapper/resource'

require 'praxis-mapper/query/base'
require 'praxis-mapper/query/sql'
require 'praxis-mapper/query/sequel'


require 'praxis-mapper/config_hash'
