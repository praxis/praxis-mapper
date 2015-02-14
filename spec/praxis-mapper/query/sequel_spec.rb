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

  it 'multi_get' do
    connection.sqls.should be_empty
    query.multi_get(:id, [1,2])
    connection.sqls.should eq(["SELECT id, name FROM items WHERE ((name = 'something') AND (id IN (1, 2))) LIMIT 10"])
  end

  it 'execute' do
    connection.sqls.should be_empty
    query.execute
    connection.sqls.should eq(["SELECT id, name FROM items WHERE (name = 'something') LIMIT 10"])
  end

end

