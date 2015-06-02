require 'spec_helper'

describe Praxis::Mapper::IdentityMapExtensions::Persistence do

  let(:user) { UserModel.create }
  let(:post) { PostModel.create(title: 'title', author: user) }
  
  before do
    identity_map.add_record(post)
    identity_map.add_record(user)
    identity_map.reindex!(PostModel, :author_id)
  end

  subject(:identity_map) { Praxis::Mapper::IdentityMap.new }

  context '#attach(record)' do
    context 'for a record that is missing an identity' do
      let(:post) { PostModel.new(title: 'title') }

      it 'saves the record before adding it ' do
        post.should_receive(:save).and_call_original
        identity_map.should_receive(:add_record).with(post).and_call_original

        identity_map.attach(post)

        identity_map.get(PostModel, id: post.id).should be post
      end
    end

    context 'for a record that is not missing an identity' do
      let(:post) { PostModel.create(title: 'title') }

      it 'does not save the record before adding it' do
        post.should_not_receive(:save).and_call_original
        identity_map.should_receive(:add_record).with(post).and_call_original

        identity_map.attach(post)

        identity_map.get(PostModel, id: post.id).should be post
      end
    end
  end

  context '#flush!(object=nil)' do

    context 'with a single record' do
      it 'saves the changes' do
        post.title = 'something else'

        identity_map.flush!(post)
        post.modified?.should be false
      end
    end

    context 'for an entire model class' do
      it 'flushes every changed record' do
        post.title = 'something else'

        identity_map.flush!(PostModel)
        post.modified?.should be false
      end
    end

    context 'with no object' do
      it 'flushes every class' do
        identity_map.should_receive(:flush!).with(no_args).and_call_original
        identity_map.should_receive(:flush!).with(PostModel)
        identity_map.should_receive(:flush!).with(UserModel)


        identity_map.flush!
      end
    end
  end

  context '#remove(record)' do
    it 'detaches and deletes the record' do
      identity_map.should_receive(:detach).with(post).and_call_original
      post.should_receive(:delete)

      identity_map.remove(post)
    end
  end

  context '#detach(record)' do

    it 'unsets record identity_map and deindexes the record' do
      identity_map.should_receive(:deindex).with(post)
      identity_map.detach(post)
      post.identity_map.should be nil
    end
  end

  context '#deindex(record)' do
    let!(:original_id) { post.id }

    before do
      post.id = 100

      # build secondary index and ensure it's populated correctly
      identity_map.all(PostModel, title: [post.title]).should include post
 
      identity_map.deindex(post)
    end

    it 'cleans up all-rows index' do
      identity_map.all(PostModel).should be_empty
    end

    it 'cleans up identity indexes' do
      identity_map.all(PostModel, id: [original_id]).should be_empty
      identity_map.all(PostModel, id: [post.id]).should be_empty
    end

    it 'cleans up secondary indexes' do
      identity_map.all(PostModel, title: [post.title]).should_not include post
    end

  end


end
