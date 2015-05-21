require 'spec_helper'

describe Praxis::Mapper::ConnectionFactories::Sequel do

  let(:database) { Sequel.mock}
  let(:thread) { Thread.current }
  let(:connection_manager) { double('Praxis::Mapper::ConnectionManager', thread: thread) }

  subject(:factory) { described_class.new(connection:database) }

  context 'checkout' do
    it 'returns the connection' do
      factory.checkout(connection_manager).should be database
    end

    it 'allocates a connection to the thread of the manager' do
      database.pool.allocated.should_not have_key(thread)
      factory.checkout(connection_manager)
      database.pool.allocated.should have_key(thread)
    end

  end

  context 'release' do
    before do
      factory.checkout(connection_manager)
    end

    it 'releases the connection' do
      database.pool.allocated.should have_key(thread)
      factory.release(connection_manager, database)
      database.pool.allocated.should_not have_key(thread)
    end
  end

  context 'across multiple threads' do
    before do
      factory.checkout(connection_manager)
    end

    it 'works somehow' do
      thread_2 = Thread.new do
        connection_manager_2 = Praxis::Mapper::ConnectionManager.new
        database.pool.allocated.should_not have_key(Thread.current)
        database.pool.allocated.should have_key(thread)

        factory.checkout(connection_manager_2)
        database.pool.allocated.should have_key(Thread.current)
      end

      thread_2.join
    end
  end


end
