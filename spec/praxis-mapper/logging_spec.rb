require_relative '../spec_helper'

describe Praxis::Mapper do

  it 'has a default logger' do
    Praxis::Mapper.logger.should be_kind_of(Praxis::Mapper::NullLogger)
  end

end
