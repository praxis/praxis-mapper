require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe Praxis::Mapper do

  context '.logger' do
    it 'returns a default logger' do
      Praxis::Mapper.logger
    end

    it 'allows assignment of Praxis::Mapper logger' do
      Praxis::Mapper.logger = Logger.new(STDOUT)
    end

    it 'returns the assigned logger' do
      logger = Logger.new(STDOUT)
      Praxis::Mapper.logger = logger
      Praxis::Mapper.logger.should === logger
    end
  end

end
