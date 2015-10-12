Encoding.default_external = Encoding::UTF_8

require 'rubygems'
require 'bundler/setup'

# Configure simplecov gem (must be here at top of file)
#require 'simplecov'
#SimpleCov.start do
#  add_filter 'spec' # Don't include RSpec stuff
#end

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))




require 'praxis-mapper'
require 'active_support/core_ext/kernel'


require_relative 'support/spec_models'
require_relative 'support/spec_sequel_models'
require_relative 'support/spec_resources'
require_relative 'support/spec_sequel_resources'

require_relative 'spec_fixtures'

require 'praxis-mapper/support'

require 'randexp'
require 'factory_girl'

require 'pry'


RSpec.configure do |config|
  config.backtrace_exclusion_patterns = [
    /\/lib\d*\/ruby\//,
    /bin\//,
    /gems/,
    /spec\/spec_helper\.rb/,
    /lib\/rspec\/(core|expectations|matchers|mocks)/,
    /org\/jruby\/.*.java/
  ]

  config.include FactoryGirl::Syntax::Methods

  config.before(:suite) do
    FactoryGirl.find_definitions
    Sequel::Model.db.transaction do
      FactoryGirl.lint
      raise Sequel::Rollback
    end

    Praxis::Mapper.finalize!

    Praxis::Mapper::ConnectionManager.repository(:default, query: Praxis::Mapper::Support::MemoryQuery) do
      Praxis::Mapper::Support::MemoryRepository.new
    end

    Praxis::Mapper::ConnectionManager.repository(:sql) do
      Sequel.mock
    end

    Praxis::Mapper::IdentityMap.setup!
  end

  config.after(:each) do
    Praxis::Mapper::IdentityMap.current.clear!
  end

  config.around(:each) do |example|
    Sequel::Model.db.transaction do
      example.run
      raise Sequel::Rollback
    end
  end

end
