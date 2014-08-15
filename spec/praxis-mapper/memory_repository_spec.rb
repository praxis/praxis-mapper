require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe Praxis::Mapper::Support::MemoryRepository do

  subject(:repository) { Praxis::Mapper::Support::MemoryRepository.new }

  let(:simple_rows) {[
                       {:id => 1, :name => "george jr", :parent_id => 1, :description => "one"},
                       {:id => 2, :name => "george iii", :parent_id => 2, :description => "two"},
                       {:id => 3, :name => "george xvi", :parent_id => 2, :description => "three"}

  ]}

  let(:person_rows) {[
                       {id: 1, email: "one@example.com", address_id: 1},
                       {id: 2, email: "two@example.com", address_id: 2},
                       {id: 3, email: "three@example.com", address_id: 2}

  ]}

  before do
    repository.insert(:simple_model, simple_rows)
    repository.insert(:people, person_rows)
  end

  context 'insert' do

    it 'adds the records to the right repository collection' do
      simple_rows.each do |simple_row|
        repository.collection(:simple_model).should include(simple_row)
      end
    end

    context 'with a Model class' do
      let(:row) { {id: 4, name: "bob", parent_id: 5, description: "four"} }
      it 'adds the records to Model.table_name collection' do
        repository.insert(SimpleModel, [row])
        repository.all(:simple_model, id: 4).should =~ [row]
      end

    end
  end


  context 'all' do

    it 'retrieves all matching records' do
      repository.all(:simple_model, parent_id: 2).should =~ simple_rows[1..2]
      repository.all(SimpleModel, parent_id: 2).should =~ simple_rows[1..2]

      repository.all(:simple_model, id: 1, parent_id: 2).should be_empty
    end

  end

end
