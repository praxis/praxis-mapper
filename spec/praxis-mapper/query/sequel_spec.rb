require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')

describe Praxis::Mapper::Query::Sequel do
  let(:scope) { {} }
  let(:identity_map) { Praxis::Mapper::IdentityMap.setup!(scope) }
  let(:connection) { identity_map.connection(:sql) }

  context "without a query body" do
    subject { Praxis::Mapper::Query::Sequel.new(identity_map, ItemModel) }

    its(:sql) { should eq("SELECT * FROM items") }
  end

  subject(:query) do
    Praxis::Mapper::Query::Sequel.new(identity_map, ItemModel) do
      select :id
      select :name
      where name: 'something'
      limit 10
    end
  end


  its(:select) { should eq({:id=>nil, :name=>nil}) }
  its(:where) { should eq({name: 'something'}) }
  its(:limit) { should eq(10) }

  its(:sql) { should eq("SELECT id, name FROM items WHERE (name = 'something') LIMIT 10")}

  context 'multi_get' do
    it 'runs the correct sql' do
      connection.sqls.should be_empty
      query.multi_get(:id, [1,2])
      connection.sqls.should eq(["SELECT id, name FROM items WHERE ((name = 'something') AND (id IN (1, 2))) LIMIT 10"])
    end
  end

  context 'execute' do
    it 'runs the correct sql' do
      connection.sqls.should be_empty
      query.execute
      connection.sqls.should eq(["SELECT id, name FROM items WHERE (name = 'something') LIMIT 10"])
    end

    context 'with select :* in query' do
      it 'runs the correct sql with "SELECT *"' do
        query.select :*
        connection.sqls.should be_empty
        query.execute
        connection.sqls.should eq(["SELECT * FROM items WHERE (name = 'something') LIMIT 10"])
      end

    end

  end


  context 'with raw sql queries' do
    subject(:query) do
      Praxis::Mapper::Query::Sequel.new(identity_map, ItemModel) do
        raw 'select something from somewhere limit a-few'
      end
    end

    its(:sql) { should eq('select something from somewhere limit a-few') }
    it 'uses the raw query when executed' do
      connection.sqls.should be_empty
      query.execute
      connection.sqls.should eq(["select something from somewhere limit a-few"])
    end

    it 'warns in _execute if a dataset is passed' do
      connection.sqls.should be_empty
      query.should_receive(:warn).with("WARNING: Query::Sequel#_execute ignoring passed dataset due to previously-specified raw SQL")
      query._execute(query.dataset)
      connection.sqls.should eq(["select something from somewhere limit a-few"])
    end

  end

end
