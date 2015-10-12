require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')

# FIXME: figure out rspec's "should behave like" or whatever

describe Praxis::Mapper::Query::Sql do
  let(:scope) { {} }
  let(:unloaded_ids) { [1, 2, 3] }
  let(:identity_map) { Praxis::Mapper::IdentityMap.setup!(scope) }
  let(:connection) { identity_map.connection(:default) }


  let(:expected_ids_condition) { "id IN (#{unloaded_ids.join(", ")})" }

  context "without a query body" do
    subject { Praxis::Mapper::Query::Sql.new(identity_map, SimpleModel) }

    its(:select_clause) { should eq("SELECT *") }
    its(:from_clause) { should eq("FROM `simple_model`") }
    its(:where_clause) { should be_nil }
    its(:limit_clause) { should be_nil }

    its(:sql) { should eq("SELECT *\nFROM `simple_model`") }

    context 'with an integer value in the identity map' do
      let(:scope) { {:tenant => [:account_id, 71]} }
      its(:where_clause) { should eq("WHERE `account_id`=71") }
    end

    context 'with a string value in the identity map' do
      let(:scope) { {:tenant => [:account_id, '71']} }
      its(:where_clause) { should eq("WHERE `account_id`='71'") }
    end

    context 'with a nil value in the identity map' do
      let(:scope) { {:tenant => [:account_id, nil]} }
      its(:where_clause) { should eq("WHERE `account_id` IS NULL") }
    end

  end

  context "#raw" do
    subject do
      Praxis::Mapper::Query::Sql.new(identity_map, SimpleModel) do
        raw "SELECT id, parent_id\nFROM table\nWHERE id=123\nGROUP BY id"
      end
    end

    it 'uses the exact raw query for the final SQL statement' do
      subject.sql.should eq("SELECT id, parent_id\nFROM table\nWHERE id=123\nGROUP BY id")
    end

  end


  context "with all the fixings" do
    subject do
      Praxis::Mapper::Query::Sql.new(identity_map, SimpleModel) do
        select :id, :name
        where "deployment_id=2"
        track :parent
      end
    end

    it "generates the correct select statement" do
      str = subject.select_clause
      str.should =~ /^\s*SELECT/
      fields = str.gsub(/^\s*SELECT\s*/, "").split(',').map { |field| field.strip }
      fields.should =~ ["id", "name"]
    end

    its(:where_clause) { should eq("WHERE deployment_id=2") }

    it "should generate SQL by joining the select, from and where clauses with newlines" do
      subject.sql.should == [subject.select_clause, subject.from_clause, subject.where_clause].compact.join("\n")
    end

    context 'a scope in the identity map' do
      let(:scope) { {:tenant => [:account_id, 71]} }
      its(:where_clause) { should eq("WHERE `account_id`=71 AND deployment_id=2") }

      context 'with a nil value' do
        let(:scope) { {:deleted => [:deleted_at, nil]} }
        its(:where_clause) { should eq("WHERE `deleted_at` IS NULL AND deployment_id=2") }
      end
    end

    context 'an ignored scope in the identity map' do
      let(:scope) { {:account => [:account_id, 71]} }
      its(:where_clause) { should eq("WHERE deployment_id=2") }
    end

  end

  context 'selecting all fields' do
    subject(:query) do
      Praxis::Mapper::Query::Sql.new(identity_map, SimpleModel) do
        select :id, :name
        where "deployment_id=2"
        track :parent
      end
    end

    it 'generates proper select clause if select is true' do
      query.select :*
      query.select_clause.should eq 'SELECT *'
    end

  end
  context '#_multi_get' do

    let(:ids) { [1, 2, 3] }
    let(:names) { ["george xvi"] }
    let(:expected_id_condition) { "(id IN (#{ids.join(", ")}))" }
    let(:expected_name_condition) { "(name IN ('george xvi'))" }

    let(:query) { Praxis::Mapper::Query::Sql.new(identity_map, ItemModel) }

    it "constructs a where clause for Integer keys" do
      query.should_receive(:where).with(expected_id_condition)
      query.should_receive(:_execute)

      query._multi_get :id, ids
    end

    it "constructs a where clause for String keys" do
      query.should_receive(:where).with(expected_name_condition)
      query.should_receive(:_execute)

      query._multi_get :name, names
    end

    context "with composite identities" do

      context "where each sub-key is an Integer" do
        let(:ids) { [[1, 1], [2, 2], [3, 2]] }
        let(:expected_composite_condition) { "(((id, parent_id) IN ((1, 1), (2, 2), (3, 2))) AND (id IN (1, 2, 3)))" }
        it 'constructs a query using SQL composite constructs (parenthesis syntax)' do
          query.should_receive(:where).with(expected_composite_condition)
          query.should_receive(:_execute)

          query._multi_get [:id, :parent_id], ids
        end
      end

      context "where sub-keys are strings" do
        let(:ids) { [[1, "george jr"], [2, "george iii"], [3, "george xvi"]] }
        let(:expected_composite_condition) { "(((id, name) IN ((1, 'george jr'), (2, 'george iii'), (3, 'george xvi'))) AND (id IN (1, 2, 3)))" }
        it 'quotes only the string subkeys in the constructed composite query syntax' do
          query.should_receive(:where).with(expected_composite_condition)
          query.should_receive(:_execute)

          query._multi_get [:id, :name], ids
        end
      end
    end

    it "tracks datastore interactions" do
      query._multi_get :ids, [1,2,3]

      query.statistics[:datastore_interactions].should == 1
    end

  end




  context '#_execute' do
    let(:rows) { [
                   {:id => 1, :name => "foo", :parent_id => 1},
                   {:id => 2, :name => "bar", :parent_id => 2},
                   {:id => 3, :name => "snafu", :parent_id => 3}
    ] }

    subject(:query) { Praxis::Mapper::Query::Sql.new(identity_map, SimpleModel) }
    before do
      connection.should_receive(:fetch).and_return(rows)
      identity_map.should_receive(:connection).with(:default).and_return(connection)

      Time.should_receive(:now).and_return(Time.at(0), Time.at(10))

    end

    it 'wraps database results in SimpleModel instances' do
      records = query.execute
      records.each { |record| record.should be_kind_of(SimpleModel) }
    end

    it "tracks datastore interactions" do
      query.execute
      query.statistics[:datastore_interactions].should == 1
    end

    it 'times datastore interactions' do
      query.execute
      query.statistics[:datastore_interaction_time].should == 10
    end

    it 'warns when if a where clause and raw sql are used together' do
      query.should_receive(:warn).with("WARNING: Query::Sql#_execute ignoring requested `where` clause due to specified raw SQL")
      query.where 'id=1'
      query.raw 'select * from stuff'
      query.execute
    end

  end
end
