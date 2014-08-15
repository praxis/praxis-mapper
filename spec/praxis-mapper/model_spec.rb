require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')


describe Praxis::Mapper::Model do
  subject(:model) { SimpleModel }


  its(:excluded_scopes) { should =~ [:account] }
  its(:repository_name) { should == :default }
  its(:identities) { should =~ [:id, :name] }
  its(:table_name) { should == "simple_model" }
  its(:associations) { should have(2).items }

  let(:id) { /\d{10}/.gen.to_i }
  let(:name) { /\w+/.gen }
  let(:parent_id) { /\d{10}/.gen.to_i }
  let(:data) do
    { :id => id,
      :name => name,
      :parent_id  => parent_id
      }
  end

  let(:person_rows) {[
                       {id: 1, email: "one@example.com", address_id: 1, prior_address_ids: JSON.dump([2])},
                       {id: 2, email: "two@example.com", address_id: 2, prior_address_ids: JSON.dump([])},
                       {id: 3, email: "three@example.com", address_id: 2, prior_address_ids: JSON.dump([])}
  ]}

  let(:person_records) { person_rows.collect { |r| PersonModel.new(r) } }

  let(:address_rows) { [{id: 1, owner_id: 1},{id: 2, owner_id: 3}] }
  let(:address_records) { address_rows.collect { |r| AddressModel.new(r) } }

  let(:composite_id_rows) { [
                              {id:1, type:"foo", state:"running"},
                              {id:2, type:"bar", state:"terminated"}
  ]}

  let(:composite_id_records) { composite_id_rows.collect {|r| CompositeIdModel.new(r) } }

  let(:composite_array_rows) { [
                                 {id:1, type: 'CompositeArrayModel', composite_array_keys: JSON.dump([[1, "foo"], [2,"bar"]])},
                                 {id:2, type: 'CompositeArrayModel', composite_array_keys: JSON.dump([[1, "foo"]])}
  ]}

  let(:composite_array_records) { composite_array_rows.collect {|r| CompositeArrayModel.new(r) } }


  let(:identity_map) { Praxis::Mapper::IdentityMap.current }


  context "new-style associations" do
    subject(:person_model) { PersonModel }
    its(:associations) { should have(3).items }

    its(:associations) { should include(:properties) }
    its(:associations) { should include(:address) }
    its(:associations) { should include(:prior_addresses) }

    it 'finalizes properly' do
      person_model.associations[:properties].should == {
        model: AddressModel,
        key: :owner_id,
        primary_key: :id,
        type: :one_to_many
      }
    end

  end

  context "record finders" do

    it 'have .get' do
      identity_map.should_receive(:get).with(SimpleModel, :id => id)
      SimpleModel.get(:id => id)
    end

    it 'have .all' do
      identity_map.should_receive(:all).with(SimpleModel, :id => id)
      SimpleModel.all(:id => id)
    end

  end

  context "with a record" do

    subject { SimpleModel.new(data) }

    its(:id) { should == id }
    its(:name) { should == name }
    its(:parent_id) { should == parent_id }
    its(:_resource) { should be_nil }

    before do
      identity_map.add_records([subject])
    end


    context 'creating accessors' do

      context 'for identities and attributes' do
        let(:model) do
          Class.new(Praxis::Mapper::Model) do
            identity :id
          end
        end
        before do
          model.finalize!
        end
        subject { model.new(data) }

        it 'eagerly defines accessors for identities'do
          
          subject.methods.should include(:id)
        end

        it 'lazily defines accessors for other attributes' do
          subject.methods.should_not include(:name)
          subject.name
          subject.methods.should include(:name)
        end
      end

      context 'for associations' do
        context 'that are many_to_one' do

          it { should respond_to(:parent) }

          it 'retrieves related records' do
            parent_record = double("parent_record")

            identity_map.should_receive(:get).with(ParentModel, :id => parent_id).and_return(parent_record)
            subject.parent.should == parent_record
          end

          context 'where the source_key value is nil' do
            subject { SimpleModel.new(data.merge(:parent_id=>nil)) }
            it 'returns nil' do
              Praxis::Mapper::IdentityMap.current.should_not_receive(:get)
              subject.parent.should be_nil
            end
          end

        end

        context 'that involve a serialized array' do

          before do
            identity_map.add_records(person_records)
            identity_map.add_records(address_records)
          end

          context 'array_to_many' do
            subject(:person_record) { person_records[0] }
            its(:prior_addresses) { should =~ address_records[1..1] }
          end

          context 'many_to_array' do
            subject(:address_record) { address_records[1] }
            its(:prior_residents) { should =~ person_records[0..0] }
          end

        end

        context 'that involve a serialized array with composite keys' do

          before do
            identity_map.add_records(composite_id_records)
            identity_map.add_records(composite_array_records)
          end

          context 'array_to_many' do
            subject(:composite_array_record) { composite_array_records[0] }
            its(:composite_id_models) { should =~ composite_id_records }
          end

          context 'many_to_array' do
            subject(:composite_id_record) { composite_id_records[0] }
            its(:composite_array_models) { should =~ composite_array_records }
          end
        end

        context 'that are one_to_many' do
          subject(:address_record) { address_records.first }

          before do
            identity_map.add_records(person_records)
            identity_map.add_records(address_records)
          end

          it { should respond_to(:owner) }
          it { should respond_to(:residents) }

          its(:owner) { should be(person_records[0]) }
          its(:residents) { should =~ person_records[0..0] }

          context 'for a composite key' do

            let(:other_records) {[
                                   OtherModel.new(id:10, composite_id:1, composite_type:"foo", name:"something"),
                                   OtherModel.new(id:11, composite_id:1, composite_type:"foo", name:"nothing"),
                                   OtherModel.new(id:12, composite_id:1, composite_type:"bar", name:"nothing")
            ]}

            subject(:composite_record) { composite_id_records.first }

            before do
              identity_map.add_records(composite_id_records)
              identity_map.add_records(other_records)
            end

            its(:other_models) { should =~ other_records[0..1] }

          end
        end




      end


    end

    it 'does respond_to attributes in the underlying record' do
      subject.should respond_to(:id)
      subject.should respond_to(:name)
      subject.should respond_to(:parent_id)
    end

    it 'does not respond_to attributes not in the underlying record' do
      subject.should_not respond_to(:foo)
    end

    it 'raises NoMethodError for undefined attributes' do
      expect { subject.foo }.to raise_error(NoMethodError)
    end

  end

  context 'supports composite identities' do
    subject { CompositeIdModel }
    its(:identities) { should =~ [[:id, :type]] }
  end

  #TODO: Refactor these cases...yaml and json serialization are exactly the same test...except for using YAML or JSON class
  context 'serialized attributes' do
    context 'yaml attributes' do
      let(:model) { YamlArrayModel }
      let(:names) { ["george jr", "george iii"] }
      let(:parent_ids) { [1,2] }

      let(:record) {
        model.new(:id => 1,
                  :parent_ids => YAML.dump(parent_ids),
                  :names => YAML.dump(names)
                  )
      }


      it 'de-serializes in the accessor' do
        record.should respond_to(:names)
        record.names.should =~ names
      end

      it 'memoizes the de-serialization in the accessor' do
        YAML.should_receive(:load).with(YAML.dump(names)).once.and_call_original
        2.times { record.names }
      end

      it 'defines an accessor for the raw yaml string' do
        record.should respond_to(:_raw_names)
        record._raw_names.should == YAML.dump(names)
      end

      context "with a nil value" do
        let(:record) {
          model.new(:id => 1,
                    :parent_ids => nil,
                    :names => nil
                    )
        }

        it 'returns nil if no default value was specified' do
          record.names.should be_nil
        end

        it 'returns the default value if specified' do
          record.parent_ids.should == []
        end

      end

    end

    context 'json attributes' do
      let(:model) { JsonArrayModel }
      let(:names) { ["george jr", "george iii"] }
      let(:parent_ids) { [1,2] }

      let(:record) {
        model.new(:id => 1,
                  :parent_ids => JSON.dump(parent_ids),
                  :names => JSON.dump(names)
                  )
      }


      it 'de-serializes in the accessor' do
        record.should respond_to(:names)
        record.names.should =~ names
      end

      it 'memoizes the de-serialization in the accessor' do
        JSON.should_receive(:load).with(JSON.dump(names)).once.and_call_original
        2.times { record.names }
      end

      it 'defines an accessor for the raw yaml string' do
        record.should respond_to(:_raw_names)
        record._raw_names.should == JSON.dump(names)
      end

      context "with a nil value" do
        let(:record) {
          model.new(:id => 1,
                    :parent_ids => nil,
                    :names => nil
                    )
        }

        it 'returns nil if no default value was specified' do
          record.names.should be_nil
        end

        it 'returns the default value if specified' do
          record.parent_ids.should == []
        end

      end

    end
  end

  context '.context' do
    let(:model_class) { PersonModel }

    it 'works' do
      PersonModel.contexts[:default][:select].should be_empty
      PersonModel.contexts[:default][:track].should eq [:address]
    end

    context 'with nested tracks' do
      it 'works too' do
        name, block = PersonModel.contexts[:addresses][:track][0]
        name.should be(:address)
        block.should be_kind_of(Proc)
        Praxis::Mapper::ConfigHash.from(&block).to_hash.should eq({context: :default})

        PersonModel.contexts[:addresses][:track][1].should be(:prior_addresses)
      end
    end

  end
  
  context '#inspect' do
    subject(:inspectable) { PersonModel.new( person_rows.first ) }
    its(:inspect){ should =~ /@data: /}
    its(:inspect){ should =~ /@deserialized_data: /}
    its(:inspect){ should_not =~ /@query: /}
    its(:inspect){ should_not =~ /@identity_map: /}
  end

  context '#identities' do
    context 'with simple keys' do
      subject(:record) { person_records.first }

      its(:identities) { should eq(id: record.id, email: record.email)}
    end

    context 'with composite keys' do
      subject(:record) { composite_id_records.first }
      its(:identities) { should eq({[:id, :type] => [record.id, record.type]})}
    end

  end

end
