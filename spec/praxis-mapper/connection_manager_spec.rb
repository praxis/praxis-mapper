require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

class DummyFactory
  def initialize(opts)
    @opts = opts
  end

  def opts
    @opts
  end

  def checkout
  end

  def release(connection)
  end

end


describe Praxis::Mapper::ConnectionManager do
  let(:mock_connection) { double("connection") }

  let(:default_hash) { Hash.new }
  let(:factory_opts) { {:foo => "bar"} }
  let(:config) { {:dummy => {:connection_factory => "DummyFactory", :connection_opts => factory_opts}} }

  let(:dummy_factory_mock) { double("dummy_factory")}

  subject { Praxis::Mapper::ConnectionManager }
  
  before do
    Praxis::Mapper::ConnectionManager.setup(config)
  end

  it 'has a :dummy repository' do
    repository = subject.repository(:dummy)

    repository[:connection_factory].should be_kind_of(DummyFactory)
    repository[:connection_factory].opts.should == factory_opts
  end

  context "with repositories specified in a block for setup" do
    let(:dummy_connection) { double("dummy connection")}

    before do
      opts = factory_opts
      
      block = Proc.new { mock_connection }
      Praxis::Mapper::ConnectionManager.setup do
        repository :foo, &block
        repository :bar, :connection_factory => "DummyFactory", :connection_opts => opts
      end
    end

    it 'supports proc-based repostories' do
      subject.repository(:foo)[:connection_factory].should be_kind_of(Proc)
    end

    it 'supports config-based repositories' do
      subject.repository(:bar)[:connection_factory].should be_kind_of(DummyFactory)
      subject.repository(:bar)[:connection_factory].opts.should == factory_opts
    end

    context 'getting connections' do
      
      subject { Praxis::Mapper::ConnectionManager.new }

      it 'gets connections from proc-based repositories' do
        subject.checkout(:foo).should == mock_connection
      end

      it 'gets connections from config-based repositories' do
        DummyFactory.any_instance.should_receive(:checkout).and_return(dummy_connection)
        subject.checkout(:bar).should == dummy_connection
      end

    end

    context 'releasing connections' do
      subject { Praxis::Mapper::ConnectionManager.new }

      it 'releases connections from config-based repositories' do

        DummyFactory.any_instance.should_receive(:checkout).exactly(2).times.and_return(dummy_connection)
        DummyFactory.any_instance.should_receive(:release).with(dummy_connection).and_return(true)

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
        DummyFactory.any_instance.should_receive(:checkout).exactly(1).times.and_return(dummy_connection)
        DummyFactory.any_instance.should_receive(:release).with(dummy_connection).and_return(true)

        subject.checkout(:bar)

        subject.should_not_receive(:release_one).with(:foo).and_call_original
        subject.should_receive(:release_one).with(:bar).and_call_original
        
        subject.release
      end

    end


  end
end
