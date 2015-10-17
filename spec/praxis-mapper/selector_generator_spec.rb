require 'spec_helper'

describe Praxis::Mapper::SelectorGenerator do
  let(:properties) { {} }

  subject(:generator) {Praxis::Mapper::SelectorGenerator.new }

  before do
    generator.add(BlogResource,properties)
  end
  it 'has specs for many_to_many associations'
  let(:expected_selectors) { {} }

  context 'for a simple field' do
    let(:properties) { {id: true} }
    let(:expected_selectors) do
      {
        BlogModel => {
          select: Set.new([:id]),
          track: Set.new()
        }
      }
    end

    it 'generates the correct set of selectors' do
      generator.selectors.should eq expected_selectors
    end
  end

  context 'for a simple property' do
    let(:properties) { {display_name: true} }
    let(:expected_selectors) do
      {
        BlogModel => {
          select: Set.new([:name]),
          track: Set.new()
        }
      }
    end
    it 'generates the correct set of selectors' do
      generator.selectors.should eq expected_selectors
    end
  end

  context 'for an association' do
    let(:properties) { {owner: true} }
    let(:expected_selectors) do
      {
        BlogModel => {
          select: Set.new([:owner_id]),
          track: Set.new([:owner])
        }
      }
    end
    it 'generates the correct set of selectors' do
      generator.selectors.should eq expected_selectors
    end
  end

  context 'for a property that specifies a field from an association' do
    let(:properties) { {owner_email: true} }
    let(:expected_selectors) do
      {
        BlogModel => {
          select: Set.new([:owner_id]),
          track: Set.new([:owner])
        },
        UserModel => {
          select: Set.new([:email]),
          track: Set.new()
        }
      }
    end

    it 'generates the correct set of selectors' do
      generator.selectors.should eq expected_selectors
    end
  end

  context 'for a simple property that requires all fields' do
    let(:properties) { {everything: true} }
    let(:expected_selectors) do
      {
        BlogModel => {
          select: true,
          track: Set.new()
        }
      }
    end
    it 'generates the correct set of selectors' do
      generator.selectors.should eq expected_selectors
    end
  end

  context 'for property that uses an associated property' do
    let(:properties) { {owner_full_name: true} }
    let(:expected_selectors) do
      {
        BlogModel => {
          select: Set.new([:owner_id]),
          track: Set.new([:owner])
        },
        UserModel => {
          select: Set.new([:first_name, :last_name]),
          track: Set.new()
        }
      }
    end
    it 'generates the correct set of selectors' do
      generator.selectors.should eq expected_selectors
    end
  end


  context 'for a property that requires all fields from an association' do
    let(:properties) { {everything_from_owner: true} }
    let(:expected_selectors) do
      {
        BlogModel => {
          select: Set.new([:owner_id]),
          track: Set.new([:owner])
        },
        UserModel => {
          select: true,
          track: Set.new()
        }
      }
    end
    it 'generates the correct set of selectors' do
      generator.selectors.should eq expected_selectors
    end
  end

  context 'with a property that groups multiple fields' do
    let(:properties) { {owner_full_name: {first: true}} }
    let(:expected_selectors) do
      {
        BlogModel => {
          select: Set.new([:owner_id]),
          track: Set.new([:owner])
        },
        UserModel => {
          select: Set.new([:first_name, :last_name]),
          track: Set.new()
        }
      }
    end
    it 'generates selectors that ignore any unapplicable subrefinements' do
      generator.selectors.should eq expected_selectors
    end
  end

  context 'for a property with no dependencies' do
    let(:properties) { {id: true, kind: true} }
    let(:expected_selectors) do
      {
        BlogModel => {
          select: Set.new([:id]),
          track: Set.new()
        }
      }
    end
    it 'generates the correct set of selectors' do
      generator.selectors.should eq expected_selectors
    end
  end

  context 'with large set of properties' do

    let(:properties) do
      {
        display_name: true,
        owner: {
          id: true,
          full_name: true,
          blogs_summary: {href: true, size: true},
          main_blog: {id: true},
        },
        administrator: {id: true, full_name: true}
      }
    end

    let(:expected_selectors) do
      {
        BlogModel=> {
          select: Set.new([:id, :name, :owner_id, :administrator_id]),
          track: Set.new([:owner, :administrator])
        },
        UserModel=> {
          select: Set.new([:id, :first_name, :last_name, :main_blog_id]),
          track: Set.new([:blogs, :main_blog])
        }
      }
    end

    it 'generates the correct set of selectors' do
      generator.selectors.should eq(expected_selectors)
    end
  end

end
