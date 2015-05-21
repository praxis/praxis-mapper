require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

class DummyFactory
  attr_reader :opts
  def initialize(opts)
    @opts = opts
  end

  def checkout(connection_manager)
  end

  def release(connection_manager, connection)
  end

end

describe Praxis::Mapper::ConnectionManager do
  let(:mock_connection) { double("connection") }

  let(:default_hash) { Hash.new }
  let(:factory_opts) { {:foo => "bar"} }

  let(:dummy_connection) { double("dummy connection")}
  let(:dummy_factory_mock) { double("dummy_factory")}

  subject(:connection_manager) { Praxis::Mapper::ConnectionManager }

  before do
    opts = factory_opts
    block = Proc.new { mock_connection }

    Praxis::Mapper::ConnectionManager.setup do
      repository :foo, &block
      repository :bar, :factory => "DummyFactory", :opts => opts
    end
  end

  it 'supports proc-based repostories' do
    subject.repository(:foo)[:factory].should be_kind_of(Praxis::Mapper::ConnectionFactories::Simple)
  end

  it 'supports config-based repositories' do
    subject.repository(:bar)[:factory].should be_kind_of(DummyFactory)
    subject.repository(:bar)[:factory].opts.should == factory_opts
  end

  context 'getting connections' do

    subject { Praxis::Mapper::ConnectionManager.new }

    it 'gets connections from proc-based repositories' do
      subject.checkout(:foo).should == mock_connection
    end

    it 'gets connections from config-based repositories' do
      DummyFactory.any_instance.should_receive(:checkout).with(subject).and_return(dummy_connection)
      subject.checkout(:bar).should == dummy_connection
    end

  end

  context 'releasing connections' do
    subject { Praxis::Mapper::ConnectionManager.new }

    it 'releases connections from config-based repositories' do
      DummyFactory.any_instance.should_receive(:checkout).with(subject).exactly(2).times.and_return(dummy_connection)
      DummyFactory.any_instance.should_receive(:release).with(subject, dummy_connection).and_return(true)

      subject.checkout(:bar)
      subject.checkout(:bar)

      subject.release(:bar)

      subject.checkout(:bar)
    end

    it 'releases connections from proc-based repositories' do
      subject.checkout(:foo)
      subject.release(:foo)
    end

    it 'releases all connections' do
      DummyFactory.any_instance.should_receive(:checkout).with(subject).exactly(1).times.and_return(dummy_connection)
      DummyFactory.any_instance.should_receive(:release).with(subject, dummy_connection).and_return(true)

      subject.checkout(:bar)

      subject.should_not_receive(:release_one).with(:foo).and_call_original
      subject.should_receive(:release_one).with(:bar).and_call_original

      subject.release
    end

  end
end
