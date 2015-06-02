require 'spec_helper'


describe Praxis::Mapper::SequelCompat do

  context 'class methods' do

    subject(:model) { PostModel }
    its(:identities) { should eq [:id] }
    its(:repository_name) { should be :sequel}

    it 'handles composite primary keys' do
      CommentModel.identities.should eq [[:author_id, :post_id]]
    end

  end

  context 'instances loaded through an identity map' do

    let!(:comment) { create(:comment) }
    let(:user) { comment.author }
    let(:post) { comment.post }

    let(:identity_map) { Praxis::Mapper::IdentityMap.new }

    let(:loaded_comment) { identity_map.get(CommentModel, [:author_id, :post_id] => [comment.author_id, comment.post_id]) }
    let(:loaded_post) { identity_map.get(PostModel, id: post.id) }
    let(:loaded_user) { identity_map.get(UserModel, id: user.id) }

    before do
      identity_map.load(CommentModel) do
        track :author, :post
      end
      identity_map.finalize!
    end


    it 'are actually loaded properly' do
      loaded_comment.should eq comment
      loaded_post.should eq post
      loaded_user.should eq user
    end

    it 'are not modified' do
      loaded_comment.modified?.should be false
      loaded_post.modified?.should be false
      loaded_user.modified?.should be false
    end

    context 'association accessors' do
      it 'are wired up correctly' do
        loaded_comment.author.should be loaded_user
        loaded_comment.post.should be loaded_post
      end
    end

    context 'that have composite keys' do
      let!(:composite_record) { create(:composite) }
      let!(:other_records) { create_list(:other, 5, composite: composite_record) }

      context 'tracking a one_to_many association' do
        before do
          identity_map.load(CompositeIdSequelModel) do
            track :others
          end
          identity_map.finalize!
        end

        let(:loaded_composite) do
          identity_map.get(
            CompositeIdSequelModel,
            [:id, :type] => [composite_record.id, composite_record.type])
        end



        it 'loads and handles associations properly' do
          identity_map.all(OtherSequelModel).should =~ other_records
          loaded_composite.others.should =~ other_records
        end

      end

      context 'tracking a many_to_one association' do
        before do
          identity_map.load(OtherSequelModel) do
            track :composite
          end
          identity_map.finalize!
        end

        let(:loaded_others) { identity_map.all(OtherSequelModel) }
        
        it 'loads and handles associations properly' do
          identity_map.all(CompositeIdSequelModel).should =~ [composite_record]
          loaded_others.all? do |loaded_other|
            loaded_other.composite == composite_record
          end.should be true
        end

      end

    end

  end
end
