require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')

describe Praxis::Mapper::Query::Base do
  let(:scope) { {} }
  let(:unloaded_ids) { [1, 2, 3] }
  let(:connection) { double("connection") }
  let(:identity_map) { double("identity_map", :scope => scope, :get_unloaded => unloaded_ids) }

  let(:model) { SimpleModel }

  let(:expected_ids_condition) { "id IN (#{unloaded_ids.join(", ")})" }

  let(:query) { Praxis::Mapper::Query::Base.new(identity_map, model) }
  subject { query }

  let(:rows) { [
                 {:id => 1, :name => "george jr", :parent_id => 1, :description => "one"},
                 {:id => 2, :name => "george iii", :parent_id => 2, :description => "two"},
                 {:id => 3, :name => "george xvi", :parent_id => 2, :description => "three"}
  ] }
  let(:ids) { rows.collect { |r| r[:id] } }


  context "retrieving records" do

    # TODO: refactor with shared_examples
    context "#multi_get" do

      it 'delegates to the subclass' do
        query.should_receive(:_multi_get).and_return(rows)
        response = query.multi_get(:id, ids)

        response.should have(3).items

        response.should eq(rows)
        #record = response.first
        #record.should be_kind_of(model)

        #rows.first.each do |attribute, value|
        #  record.send(attribute).should == value
        #end

      end

      it 'raises if run on a frozen query' do
        query.freeze
        expect { query.multi_get(:id, ids) }.to raise_error(TypeError)
      end

      context 'for very large lists of values' do
        let(:batch_size) { Praxis::Mapper::Query::Base::MULTI_GET_BATCH_SIZE }


        let(:result_size) { (batch_size * 2.5).to_i }

        let(:values) { (0..result_size).to_a }
        let(:rows) { values.collect { |v| {:id => v} } }

        before do
          stub_const("Praxis::Mapper::Query::Base::MULTI_GET_BATCH_SIZE", 4)

          rows.each_slice(batch_size) do |batch_rows|
            ids = batch_rows.collect { |v| v.values }.flatten
            query.should_receive(:_multi_get).with(:id, ids).and_return(batch_rows)
          end
        end

        it 'batches queries and aggregates their results' do # FIXME: totally lame name for this
          query.multi_get(:id, values).should =~ rows
        end
      end
    end

    context "#execute" do
      it 'delegates to the subclass and wraps the response in model instances' do
        query.should_receive(:_execute).and_return(rows)
        response = query.execute

        response.should have(3).items

        item = response.first
        item.should be_kind_of(model)

        rows.first.each do |attribute, value|
          item.send(attribute).should == value
        end

      end

      it 'raises if run on a frozen query' do
        query.freeze
        expect { query.execute }.to raise_error(TypeError)
      end

    end

    it 'raises for subclass methods' do
      expect { subject._multi_get(nil, nil) }.to raise_error "subclass responsibility"
      expect { subject._execute }.to raise_error "subclass responsibility"
    end
  end


  context "the specification DSL" do

    context "#select" do
      it "accepts an array of symbols" do
        subject.select :id, :name
        subject.select.should include(:id => nil, :name => nil)
      end

      it "accepts an array of strings" do
        subject.select "id", "name"
        subject.select.should include("id" => nil, "name" => nil)
      end

      it "raises for unknown field types" do
        expect { subject.select Object.new }.to raise_error
      end

      context "accepts an array of hashes" do
        context "with strings for the field definitions" do
          it "and symbols to specify the field aliases" do
            definition = {:id => "IFNULL(foo,bar)", :name => "CONCAT(foo,bar)"}
            subject.select definition
            subject.select.should include(definition)
          end
          it "and strings to specify the field aliases" do
            definition = {"id" => "IFNULL(foo,bar)", "name" => "CONCAT(foo,bar)"}
            subject.select definition
            subject.select.should include(definition)
          end
        end

        context "with symbols for the field definitions" do
          it "and symbols to specify the field aliases" do
            definition = {:my_id => :id, :name => :name}
            subject.select :my_id => :id, :name => :name
            subject.select.should include :my_id => :id, :name => :name
          end
          it "and strings to specify the field aliases" do
            definition = {"id" => "IFNULL(foo,bar)", "name" => "CONCAT(foo,bar)"}
            subject.select definition
            subject.select.should include(definition)
          end
        end

      end
      it "accepts an array of mixed hashes and symbols and strings" do
        subject.select :id, "description", :name => "CONCAT(foo,bar)"
        subject.select.should include(:id => nil, "description" => nil, :name => "CONCAT(foo,bar)")
      end

      it "also accepts a single symbol" do
        subject.select :id
        subject.select.should include(:id => nil)
      end

      it "also accepts a single hash" do
        definition = {:id => "IFNULL(foo,bar)"}
        subject.select definition
        subject.select.should include(definition)
      end

    end

    context "with no query body" do
      subject { Praxis::Mapper::Query::Base.new(identity_map, model) }

      it "should be an empty nil" do
        subject.select.should be_nil
      end

      its(:where) { should be_nil }
      its(:track) { should eq(Set[]) }

      context "with all the fixings" do
        subject do
          Praxis::Mapper::Query::Base.new(identity_map, model) do
            select :id, :name
            where "deployment_id=2"
            track :parent
          end
        end


        its(:select) { should == {:id => nil, :name => nil} }
        its(:where) { should eq("deployment_id=2") }
        its(:track) { should eq(Set[:parent]) }

        its(:tracked_associations) { should =~ [model.associations[:parent]] }

      end

    end

    context '#track' do
      context 'with nested track something or another' do
        subject :query do
          Praxis::Mapper::Query::Base.new(identity_map, PersonModel) do
            track :address do
              select :id, :name
              track :residents
            end
          end
        end

        it 'saves the subcontext block' do
          query.track.should have(1).item

          name, tracked_address = query.track.first
          name.should be(:address)
          tracked_address.should be_kind_of(Proc)
        end

        its(:tracked_associations) { should =~ [PersonModel.associations[:address]] }

      end

      context 'tracking an association tracked by a context' do
        subject :query do
          Praxis::Mapper::Query::Base.new(identity_map, PersonModel) do
            context :default
            track :address do
              select :id, :name
              track :residents
            end
          end
        end

        it 'retains both values' do
          query.track.should have(2).item

          query.track.should include(:address)

          # TODO: find a better way to do this match
          name, tracked_address = query.track.to_a[1]
          name.should be(:address)
          tracked_address.should be_kind_of(Proc)
        end

        its(:tracked_associations) { should =~ [PersonModel.associations[:address]] }

      end
    end

    context '#context' do
      let(:model) { PersonModel }

      subject do
        Praxis::Mapper::Query::Base.new(identity_map, model) do
          context :default
          context :tiny
          track :properties
        end
      end

      its(:select) { should eq({id: nil, email: nil}) }
      its(:track) { should eq(Set[:address, :properties]) }

    end

    context '#load' do
      subject do
        Praxis::Mapper::Query::Base.new(identity_map, model) do
          load :address
        end
      end

      its(:load) { should eq(Set[:address])}
    end
  end

  context 'statistics' do
    its(:statistics) { should == Hash.new }

    it 'initialize new values with zero' do
      subject.statistics[:execute].should == 0
    end

    context "#execute" do
      before do
        query.should_receive(:_execute).and_return(rows)
        query.execute
      end

      it 'tracks the number of calls' do
        query.statistics[:execute].should == 1
      end
      it 'tracks records loaded' do
        query.statistics[:records_loaded].should == rows.size
      end

    end

    context "#multi_get" do
      before do
        query.should_receive(:_multi_get).with(:id, ids).and_return(rows)
        query.multi_get(:id, ids)
      end

      it 'tracks the number of calls' do
        query.statistics[:multi_get].should == 1
      end
      it 'tracks records loaded' do
        query.statistics[:records_loaded].should == rows.size
      end

    end
  end

  context "#raw" do
    let(:model) { PersonModel }

  end

end
