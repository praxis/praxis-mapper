require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe Praxis::Mapper::IdentityMap do
  let(:scope) { {} }
  let(:model) { SimpleModel }

  subject(:identity_map) { Praxis::Mapper::IdentityMap.new(scope) }

  let(:repository) { subject.connection(:default) }

  let(:rows) {[
                {:id => 1, :name => "george jr", :parent_id => 1, :description => "one"},
                {:id => 2, :name => "george iii", :parent_id => 2, :description => "two"},
                {:id => 3, :name => "george xvi", :parent_id => 2, :description => "three"}

  ]}

  let(:person_rows) {[
                       {id: 1, email: "one@example.com", address_id: 1, prior_address_ids:JSON.dump([2,3])},
                       {id: 2, email: "two@example.com", address_id: 2, prior_address_ids:JSON.dump([2,3])},
                       {id: 3, email: "three@example.com", address_id: 2, prior_address_ids: nil},
                       {id: 4, email: "four@example.com", address_id: 3, prior_address_ids: nil},
                       {id: 5, email: "five@example.com", address_id: 3, prior_address_ids: nil}

  ]}

  let(:address_rows) {[
                        {id: 1, owner_id: 1, state: 'OR'},
                        {id: 2, owner_id: 3, state: 'CA'},
                        {id: 3, owner_id: 1, state: 'OR'}
  ]}

  before do
    repository.clear!
    repository.insert(SimpleModel, rows)
    repository.insert(PersonModel, person_rows)
    repository.insert(AddressModel, address_rows)
  end


  context ".setup!" do

    context "with an identity map" do
      before do
        Praxis::Mapper::IdentityMap.current = Praxis::Mapper::IdentityMap.new(scope)
      end

      context 'that has been cleared' do
        before do
          Praxis::Mapper::IdentityMap.current.clear!
        end

        it 'returns the identity_map' do
          Praxis::Mapper::IdentityMap.setup!(scope).should be_kind_of(Praxis::Mapper::IdentityMap)
        end

        it 'sets new scopes correctly' do
          Praxis::Mapper::IdentityMap.setup!({:foo => :bar}).scope.should_not be scope
        end
      end

    end

  end


  context ".current" do
    it 'setting' do
      Praxis::Mapper::IdentityMap.current = subject
      Thread.current[:_praxis_mapper_identity_map].should be(subject)
    end

    it 'getting' do
      Thread.current[:_praxis_mapper_identity_map] = subject
      Praxis::Mapper::IdentityMap.current.should be(subject)
    end
  end


  context "#connection" do
    let(:connection) { double("connection") }
    it 'proxies through to the ConnectionManager' do
      Praxis::Mapper::ConnectionManager.any_instance.should_receive(:checkout).with(:default).and_return(connection)

      subject.connection(:default).should == connection
    end
  end


  context "#load" do
    let(:query_proc) { Proc.new { } }
    let(:query_mock) { double("query mock", track: Set.new, where: nil, load: Set.new) }


    context 'with normal queries' do
      let(:record_query) do
        Praxis::Mapper::Support::MemoryQuery.new(identity_map, model) do
        end
      end

      let(:records) { rows.collect { |row| m = model.new(row); m._query = record_query; m } }

      it 'builds a query, executes, freezes it, and returns the query results' do
        Praxis::Mapper::Support::MemoryQuery.any_instance.should_receive(:execute).and_return(records)
        Praxis::Mapper::Support::MemoryQuery.any_instance.should_receive(:freeze)
        identity_map.load(model, &query_proc).should === records
      end

    end

    context 'where :staged' do
      after do
        identity_map.load AddressModel do
          where :staged
          track :foobar
        end
      end
      it 'calls finalize_model!' do
        identity_map.should_receive(:finalize_model!).with(AddressModel, anything())
      end
      it 'removes the :staged from the query where clause' do
        identity_map.should_receive(:finalize_model!) do |model, query|
          model.should be(AddressModel)
          query.where.should be(nil)
          query.track.should eq(Set.new([:foobar])) 
        end
      end
    end

    context 'with a query with a subload' do
      context 'for a many_to_one association' do
        before do
          identity_map.load PersonModel do
            load :address
          end
        end
        it 'loads the association records' do
          identity_map.all(PersonModel).should have(5).items
          identity_map.all(AddressModel).should have(3).items
        end
      end
    end

    context 'for a one_to_many association' do
      before do
        identity_map.load AddressModel do
          load :residents
        end
      end
      it 'loads the association records' do
        identity_map.all(PersonModel).should have(5).items
        identity_map.all(AddressModel).should have(3).items
      end
    end

    context 'with nested loads and preexisting records loaded' do
      before do
        identity_map.load AddressModel do
          where id: 2
        end

        identity_map.load PersonModel do
          where id: 1
          load :prior_addresses do
            load :owner
          end
        end
      end

      it 'works' do
        expect { identity_map.get(PersonModel, id: 3) }.to_not raise_error
      end
    end


    context 'with nested loads with a where clause' do
      before do
        identity_map.load PersonModel do
          where id: 2
          load :prior_addresses do
            where state: 'CA'
            load :owner
          end
        end
      end

      it 'applies the where clause to the nested load' do
        expect { identity_map.get(AddressModel, id: 3) }.to raise_error
      end

      it 'passes the resulting records a subsequent load' do
        expect { identity_map.get(PersonModel, id: 3) }.to_not raise_error
        expect { identity_map.get(PersonModel, id: 1) }.to raise_error
      end
    end


  end



  context "#get_staged" do
    let(:stage) { {:id => [1,2], :names => ["george jr", "george XVI"]} }
    before do
      identity_map.get_staged(model,:id).should == Set.new
      identity_map.stage(model, stage)
    end

    it 'supports getting ids for a single identity' do
      identity_map.get_staged(model, :id).should == Set.new(stage[:id])
    end

  end


  context "#stage" do

    before do
      identity_map.stage(model, stage)
    end


    context "with one item for one identity" do
      let(:stage) { {:id => 1} }

      it 'stages the key' do
        identity_map.get_staged(model,:id).should == Set.new([1])
      end
    end

    context "with multiple items for one identity" do
      let(:stage) { {:id => [1,2]} }

      it 'stages the keys' do
        identity_map.get_staged(model,:id).should == Set.new(stage[:id])
      end
    end

    context 'with multiple items for multiple identities' do
      let(:stage) { {:id => [1,2], :names => ["george jr", "george XVI"]} }


      it 'stages the keys' do
        stage.each do |identity,values|
          identity_map.get_staged(model,identity).should == Set.new(values)
        end
      end

    end

  end


  context '#stage when staging something we already have loaded' do

    before do
      identity_map.load(model)
      identity_map.get_staged(model,:id).should == Set.new
    end

    it 'is ignored' do
      identity_map.stage(model, :id => [1] )
      identity_map.get_staged(model,:id).should == Set.new
    end
  end



  context "#finalize_model!" do

    context 'with values staged for a single identity' do
      let(:stage) { {:id => [1,2] } }

      before do
        identity_map.stage(model, stage)
      end

      it "does a multi-get for the unloaded ids and returns the query results" do
        Praxis::Mapper::Support::MemoryQuery.any_instance.
          should_receive(:multi_get).
          with(:id, Set.new(stage[:id])).
          and_return(rows[0..1])
        Praxis::Mapper::Support::MemoryQuery.any_instance.should_receive(:freeze)

        identity_map.finalize_model!(model).collect(&:id).should =~ rows[0..1].collect { |r| r[:id] }
      end

      context 'tracking associations' do
        let(:track) { :parent }

        it 'sets the track attribute on the generated query' do
          Praxis::Mapper::Support::MemoryQuery.any_instance.should_receive(:multi_get).with(:id, Set.new(stage[:id])).and_return(rows[0..1])
          Praxis::Mapper::Support::MemoryQuery.any_instance.should_receive(:track).with(track).at_least(:once).and_call_original
          Praxis::Mapper::Support::MemoryQuery.any_instance.should_receive(:track).at_least(:once).and_call_original
          Praxis::Mapper::Support::MemoryQuery.any_instance.should_receive(:freeze)

          track_field = track
          query = Praxis::Mapper::Support::MemoryQuery.new(identity_map,model) do
            track track_field
          end

          identity_map.finalize_model!(model, query)
        end
      end

    end


    context 'with values staged for multiple identities' do
      let(:stage) { {:id => [1,2], :name => ["george jr", "george xvi"]} }

      before do
        identity_map.stage(model, stage)
      end

      it 'does a multi_get for ids, then one for remaining names, freezes the query, and consolidated query reults' do
        query = Praxis::Mapper::Support::MemoryQuery.new(identity_map, model)
        Praxis::Mapper::Support::MemoryQuery.stub(:new).and_return(query)

        query.should_receive(:multi_get).with(:id, Set.new(stage[:id])).and_return(rows[0..1])
        query.should_receive(:multi_get).with(:name, Set.new(['george xvi'])).and_return([rows[2]])
        query.should_receive(:freeze).once

        expected = rows.collect { |r| r[:id] }
        result = identity_map.finalize_model!(model)

        result.collect(&:id).should =~ expected
      end

    end

    context 'with unfound values remaining at the end of finalizing' do
      let(:stage) { {:id => [1,2,4] } }

      before do
        identity_map.stage(model, stage)

        Praxis::Mapper::Support::MemoryQuery.any_instance.should_receive(:multi_get).with(:id, Set.new(stage[:id])).and_return(rows[0..1])
        Praxis::Mapper::Support::MemoryQuery.any_instance.should_receive(:freeze)
      end

      it 'adds the missing keys to the identity map with nil values' do
        identity_map.finalize_model!(model)
        identity_map.get(model,:id => 4).should be_nil
      end


    end

    context 'with values staged for a non-identity key' do
      let(:model) { AddressModel }
      let(:stage) {{
                     id: Set.new([1,2]),
                     owner_id: Set.new([1,2,3])
      }}

      before do
        identity_map.stage(model, stage)
        owner_id_response = [{id:1}, {id:2}]

        query = Praxis::Mapper::Support::MemoryQuery.new(identity_map, model)
        Praxis::Mapper::Support::MemoryQuery.stub(:new).and_return(query)

        query.should_receive(:multi_get).
          with(:owner_id, Set.new(stage[:owner_id]), select: [:id]).ordered.and_return(owner_id_response)
        query.should_receive(:multi_get).
          with(:id, Set.new(stage[:id])).ordered.and_return(person_rows)

        query.should_receive(:freeze)
      end

      it 'first resolves staged non-identity keys to identities' do
        identity_map.finalize_model!(model)
      end

    end


    context 'for a model with _queries staged for it too....' do

      before do
        identity_map.clear!
        identity_map.load(PersonModel) do
          where id: 2
          track :address do
            context :default
          end
        end
      end


      it 'finalize_model!' do
        identity_map.finalize_model!(AddressModel)
        identity_map.get_staged(PersonModel, :id).should eq(Set[3])
      end

      it 'finalize! retrieves records for newly-staged keys.' do
        identity_map.finalize!
        identity_map.get(PersonModel, id: 3).id.should eq(3)
      end

    end


    context 'with context that includes a track with a block' do
      before do
        identity_map.clear!

        identity_map.load(AddressModel) do
          context :current
          where id: 3
        end

        identity_map.finalize!
      end

      it 'loads the owner and residents' do
        identity_map.all(PersonModel).should have(3).items
        identity_map.all(PersonModel).collect(&:id).should =~ [1,4,5]
      end

      it 'loads the owner with the :default and :tiny contexts' do
        owner = identity_map.get(PersonModel, id: 1)

        owner._query.contexts.should eq(Set[:default,:tiny])
        owner._query.track.should eq(Set[:address])
      end

      it 'loads the residents with the :default and :tiny contexts' do
        address = identity_map.get(AddressModel, id: 3)

        address.residents.should have(2).items
        address.residents.each do |resident|
          resident._query.contexts.should eq(Set[:default, :tiny])
          resident._query.track.should eq(Set[:address])
        end
      end

    end

    context 'and a where clause' do


      context 'for a many_to_one association' do
        before do
          identity_map.load PersonModel do
            track :address do
              where state: 'OR'
            end
          end
        end
        it 'raises an error ' do
          expect { identity_map.finalize!(AddressModel) }.to raise_error(/type :many_to_one is not supported/)
        end
      end

      context 'for a array_to_many association' do
        before do
          identity_map.load PersonModel do
            track :prior_addresses do
              where state: 'OR'
            end
          end
        end
        it 'raises an error ' do
          expect { identity_map.finalize!(AddressModel) }.to raise_error(/type :array_to_many is not supported/)
        end
      end

      context 'for a one_to_many association' do
        before do
          identity_map.load PersonModel do
            track :properties do
              where state: 'OR'
            end
          end
        end

        it 'honors the where clause' do
          identity_map.finalize!
          identity_map.all(AddressModel).should_not be_empty
          identity_map.all(AddressModel).all? { |address| address.state == 'OR' }.should be(true)
        end

      end
    end

  end

  context 'adding and retrieving records' do
    let(:record_query) do
      Praxis::Mapper::Support::MemoryQuery.new(identity_map, model) do
        track :parent
      end
    end

    let(:records) { rows.collect { |row| m = model.new(row); m._query = record_query; m } }

    before do
      identity_map.add_records(records)
    end


    it 'sets record.identity_map' do
      records.each { |record| record.identity_map.should be(identity_map) }
    end

    # FIXME: see similar test for unloaded keys above
    it 'round-trips nicely...' do
      identity_map.rows_for(model).should =~ records
    end

    it 'updates primary key indices' do
      identity_map.row_by_key(model,:id,1).should == records.first
      identity_map.row_by_key(model,:name,"george jr").should == records.first
    end

    it 'does not re-add existing rows' do
      new_record = SimpleModel.new(
        :id => records.first.id,
        :name => records.first.name,
        :parent_id => records.first.parent_id,
        :description => "new description"
      )
      identity_map.add_records([new_record])

      identity_map.rows_for(model).should =~ records
    end

    it 'stages tracked associations' do
      identity_map.get_staged(ParentModel,:id).should == Set.new([1,2])
    end

    context 'with a tracked array association' do
      let(:records) { [YamlArrayModel.new(:id => 1, :parent_ids => YAML.dump([1,2]) )].each { |m| m._query = records_query } }
      let(:records_query) do
        Praxis::Mapper::Support::MemoryQuery.new(identity_map, YamlArrayModel) do
          track :parents
        end
      end

      it 'stages the deserialized relationship ids' do
        identity_map.get_staged(ParentModel,:id).should == Set.new([1,2])
      end

      context 'with a nil value for the association' do
        let(:records) { [YamlArrayModel.new(:id => 1, :parent_ids => nil)] }
        let(:opts) { {:track => [:parents]} }

        it 'does not stage anything' do
          identity_map.get_staged(ParentModel,:id).should == Set.new
        end

      end
    end
  end


  context "#add_records" do


    context "with a tracked many_to_one association " do
      before do
        identity_map.load(SimpleModel) do
          track :parent
        end
      end

      it 'sets loaded records #identity_map' do
        identity_map.all(model).each { |record| record.identity_map.should be(identity_map) }
      end

      it 'adds loaded records to the identity map' do
        rows.all? do |row|
          identity_map.rows_for(model).any? { |record| record.id == row[:id] }
        end.should be(true)
      end

      it 'adds ids for tracked associations to unloaded ids' do
        identity_map.get_staged(ParentModel,:id).should == Set.new([1,2])
      end

      it 'does not add ids for untracked associations to unloaded ids' do
        identity_map.get_staged(OtherModel,:id).should == Set.new
      end

      context "loading missing ParentModel records" do
        let(:parent_rows) {[
                             {:id => 1, :name => "parent one"}
        ]}

        before do
          identity_map.get_staged(ParentModel,:id).should == Set.new([1,2])

          repository.insert(ParentModel, parent_rows)
          identity_map.load(ParentModel)
        end

        it 'removes only those ids from unloaded_ids that correspond to loaded rows' do
          identity_map.get_staged(ParentModel,:id).should == Set.new([2])
        end

      end
    end

    context 'with a tracked one_to_many association' do

      before do
        identity_map.load(PersonModel) do
          track :properties
        end
      end

      it 'adds loaded records to the identity map' do
        identity_map.rows_for(PersonModel).collect(&:id).should =~ person_rows.collect { |r| r[:id] }

      end

      it 'adds ids for tracked associations to unloaded ids' do
        identity_map.get_staged(AddressModel,:owner_id).should == Set.new([1,2,3,4,5])
      end

    end

    # TODO: track whether a model is finalized
    #it 'tracks whether a model has been finalized'

    context 'composite identity support' do
      let(:composite_id_rows) {[
                                 {:id => 1, :type => "foo", :state => "running"},
                                 {:id => 2, :type => "bar", :state => "terminated"}
      ]}

      context "loading records" do

        context "for a model with a composite identity" do
          before do
            repository.insert(CompositeIdModel, composite_id_rows)
            identity_map.load(CompositeIdModel)
          end

          it 'loads the rows normally' do
            identity_map.rows_for(CompositeIdModel).collect(&:id).should =~ composite_id_rows.collect { |r| r[:id] }
          end

          it 'indexes the rows by the composite identity' do
            identity_map.row_by_key(CompositeIdModel,[:id,:type],[1,"foo"]).state == composite_id_rows.first[:state]
          end
        end

        context 'tracking composite associations' do
          let(:child_rows) {[
                              {:id => 10, :composite_id => 1, :composite_type => "foo", :name => "something"},
                              {:id => 11, :composite_id => 2, :composite_type => "bar", :name => "nothing"}
          ]}

          before do
            repository.insert(:other_model, child_rows)
            identity_map.load(OtherModel) do
              track :composite_model
            end

          end

          it 'stages the CompositeIdModel identity' do
            identity_map.get_staged(CompositeIdModel,[:id,:type]).should == Set.new([[1,"foo"],[2,"bar"]])
          end
          context 'when one or more of the values in the composite key is nil' do
            let(:child_rows) {[
                                {:id => 10, :composite_id => 1, :composite_type => "foo", :name => "something"},
                                {:id => 11, :composite_id => nil, :composite_type => "bar", :name => "nothing"},
                                {:id => 12, :composite_id => nil, :composite_type => nil, :name => "nothing"}
            ]}
            it 'skips staging them' do
              identity_map.get_staged(CompositeIdModel,[:id,:type]).should == Set.new([[1,"foo"]])
            end
          end
        end


        context 'tracking composite associations through arrays' do
          let(:child_rows) {[
                              {id: 10,type: 'CompositeArrayModel',composite_array_keys: JSON.dump([[1,"foo"],[2,"bar"]]), name: "something"},
                              {id: 11,type: 'CompositeArrayModel',composite_array_keys: JSON.dump([[2,"bar"],[3,"baz"]]), name: "something"}
          ]}

          before do
            repository.insert(:composite_array_model, child_rows)
            identity_map.load(CompositeArrayModel) do
              track :composite_id_models
            end

          end

          it 'stages the CompositeIdModel identity' do
            identity_map.get_staged(CompositeIdModel,[:id,:type]).should == Set.new([[1,"foo"],[2,"bar"],[3,"baz"]])
          end

          context 'when one or more of the values in the composite key (for any composite values in the array) is nil' do
            let(:child_rows) {[
                                {:id => 10, :type => 'CompositeArrayModel', :composite_array_keys => JSON.dump([[1,"foo"],[2,"bar"]]),  :name => "something"},
                                {:id => 11, :type => 'CompositeArrayModel', :composite_array_keys => JSON.dump([[2,"bar"],[3,nil]]),  :name => "something"},
                                {:id => 13, :type => 'CompositeArrayModel', :composite_array_keys => JSON.dump([nil,      [4,nil]]),  :name => "something"}
            ]}
            it 'skips staging them' do
              identity_map.get_staged(CompositeIdModel,[:id,:type]).should == Set.new([[1,"foo"],[2,"bar"]])
            end
          end
        end
      end

    end

    context "#clear!" do
      let(:stage) { {:id => [3,4]} }

      before do
        identity_map.load(SimpleModel)
        identity_map.stage(model, stage)

        identity_map.rows_for(SimpleModel).should_not be_empty
        identity_map.get_staged(SimpleModel,:id).should == Set.new(stage[:id])
        identity_map.get_staged(SimpleModel,:name).should == Set.new

        identity_map.queries[SimpleModel].add(double("query"))

        identity_map.clear!
      end


      it 'resets the rows' do
        identity_map.rows_for(SimpleModel).should be_empty
      end


      it 'clears the staged rows' do
        identity_map.get_staged(SimpleModel,:id).should == Set.new
      end

      it 'clears the row keys' do
        expect { identity_map.row_by_key(SimpleModel,:id,1) }.to raise_error(Praxis::Mapper::IdentityMap::UnloadedRecordException)
      end

      it 'clears the query history' do
        identity_map.queries.should have(0).items
      end

    end

    context "#all" do

      before do
        identity_map.load(SimpleModel)
        identity_map.load(PersonModel)

        # pretend we staged :id => 4, tried to properly load it, but it
        # was not present in the database.
        identity_map.instance_variable_get(:@row_keys)[model][:id][4] = nil
      end

      it 'returns all records' do
        identity_map.all(SimpleModel).collect(&:id).should =~ rows.collect { |r| r[:id] }
      end

      it 'filters records by one id' do
        identity_map.all(SimpleModel, :id =>[1]).collect(&:id).should =~ [rows.first].collect { |r| r[:id] }
      end

      it 'filters records by multiple ids' do
        identity_map.all(SimpleModel, :id => [1,2]).collect(&:id).should =~ rows[0..1].collect { |r| r[:id] }
      end

      it 'returns an empty array if nothing was found matching a condition' do
        identity_map.all(SimpleModel, :id => [4]).should =~ []
      end

      it 'does not return nil for records that were not found' do
        results = identity_map.all(SimpleModel, :id => [1,4])
        results.should have(1).item
        results.should eq(identity_map.all(SimpleModel, :id => [1]))
      end


    end

    context '#row_by_key' do
      let(:stage) { {:id => [1,2,3,4]} }
      before do
        Praxis::Mapper::Support::MemoryQuery.any_instance.should_receive(:multi_get).with(:id, Set.new(stage[:id])).and_return(rows)
        Praxis::Mapper::Support::MemoryQuery.any_instance.should_receive(:freeze)
        identity_map.stage(model,stage)
        identity_map.finalize_model!(model)
      end

      it 'raises UnloadedRecordException for unknown records' do
        expect { identity_map.row_by_key(model,:id, 5) }.to raise_error(Praxis::Mapper::IdentityMap::UnloadedRecordException)
      end
    end

    context "#<<" do
      let(:records) { 3.times.collect { SimpleModel.generate} }

      before do
        records.each { |record| identity_map << record }
      end

      it 'stores a single record at a time' do
        identity_map.rows_for(SimpleModel).should =~ records
      end

      it 'sets loaded records #identity_map' do
        records.each { |record| record.identity_map.should be(identity_map) }
      end


    end

    context "#get" do
      before do
        identity_map.load(model)

        # pretend we staged :id => 4, tried to properly load it, but it
        # was not present in the database.
        identity_map.instance_variable_get(:@row_keys)[model][:id][4] = nil
      end

      it 'returns a single records by id' do
        identity_map.get(model, :id => 1).id.should == rows.first[:id]
      end

      it 'returns nil for a record that was not found' do
        identity_map.get(model, :id => 4).should be_nil
      end

    end




    context 'statistics tracking' do

      context 'in a new identity map' do
        its(:queries) { should have(0).items }
        it 'initializes new keys with a Set' do
          subject.queries[model].should == Set.new
        end
      end

      context 'after loading queries' do

        before do
          subject.queries[PersonModel].should have(0).item
        end

        it 'tracks for #load' do
          identity_map.load(PersonModel)

          subject.queries[PersonModel].should have(1).item
        end

        it 'tracks for #finalize_model!' do
          identity_map.stage(PersonModel, id: [1,2])
          identity_map.finalize_model!(PersonModel)

          subject.queries[PersonModel].should have(1).item
        end

      end


    end

    context 'secondary index support' do
      let(:people) { identity_map.all PersonModel }
      let(:secondary_indexes) { identity_map.instance_variable_get(:@secondary_indexes) }

      before do
        identity_map.load PersonModel
      end

      context '#index' do
        it 'lazily calls #reindex! to build secondary indexes' do
          identity_map.should_receive(:reindex!).with(PersonModel, :address_id).and_call_original

          identity_map.index(PersonModel, :address_id, 1)
        end

        it 'does not call #reindex! if not necessary' do
          identity_map.index(PersonModel, :address_id, 1)
          identity_map.should_not_receive(:reindex!)
          identity_map.index(PersonModel, :address_id, 2)
        end

        it 'supports composite keys' do
          identity_map.should_receive(:reindex!).with(PersonModel, [:id, :email]).and_call_original
          values = identity_map.index(PersonModel, [:id, :email], [1,"one@example.com"])

          person, *rest = values
          rest.should be_empty

          person.id.should eq(1)
          person.email.should eq('one@example.com')
        end
      end

      context '#reindex!' do
        it 'builds a secondary index for the given model and key' do
          identity_map.reindex!(PersonModel, :address_id)

          secondary_indexes.should have_key(PersonModel)
          secondary_indexes[PersonModel].should have_key(:address_id)
          secondary_indexes[PersonModel][:address_id].keys.should =~ person_rows.collect { |person| person[:address_id] }.uniq

          people.each do |person|
            identity_map.index(PersonModel, :address_id, person.address_id).should include(person)
          end
        end
      end

      context '#all' do
        it 'uses the index internally' do
          identity_map.should_receive(:reindex!).with(PersonModel, :address_id).and_call_original

          people = identity_map.all(PersonModel, address_id: [2])
          people.should have(2).items
          people.each { |person| person.address_id.should eq(2) }
        end
      end
    end
  end
end
