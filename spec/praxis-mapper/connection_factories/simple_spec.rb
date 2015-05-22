require 'spec_helper'

describe Praxis::Mapper::ConnectionFactories::Simple do

  let(:connection) { double("connection") }

  let(:connection_manager) { double('Praxis::Mapper::ConnectionManager') }

  context 'with a raw connection' do
    subject(:factory) { described_class.new(connection:connection) }

    it 'returns the connection on checkout' do
      factory.checkout(connection_manager).should be connection
    end

  end

  context 'with a proc' do
    let(:block) { Proc.new { connection } }

    subject(:factory) { described_class.new(&block) }
    
    it 'calls the block on checkout' do
      block.should_receive(:call).and_call_original
      factory.checkout(connection_manager).should be connection
    end
  end

end
