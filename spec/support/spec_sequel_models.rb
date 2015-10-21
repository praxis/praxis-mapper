
#Sequel::Model.db = Sequel.mock
#Sequel::Model.db.columns = [:id]

DB = Sequel.sqlite

DB.create_table! :blogs do
  primary_key :id
  Integer :owner_id
  Integer :administrator_id

  String :name
end

DB.create_table! :users do
  primary_key :id
  Integer :main_blog_id

  String :first_name
  String :last_name
  String :email
end


DB.create_table! :posts do
  primary_key :id
  Integer :author_id

  String :title
  String :body

  DateTime :created_at
end


DB.create_table! :comments do

  Integer :author_id
  Integer :post_id

  String :body

  primary_key [:author_id, :post_id]
end


DB.create_table! :composite_ids do
  String :id
  String :type

  String :name

  primary_key [:id, :type]
end

DB.create_table! :others do
  primary_key :id

  String :composite_id
  String :composite_type
end

Praxis::Mapper::ConnectionManager.setup do
  repository(:sequel, query: Praxis::Mapper::Query::Sequel) do
    DB
  end
end

class BlogModel < Sequel::Model(:blogs)
  include Praxis::Mapper::SequelCompat
  many_to_one :owner, class: 'UserModel', key: :owner_id
  many_to_one :administrator, class: 'UserModel', key: :administrator_id

end

class UserModel < Sequel::Model(:users)
  include Praxis::Mapper::SequelCompat

  repository_name :sequel

  one_to_many :posts, class: 'PostModel', key: :author_id
  one_to_many :comments, class: 'CommentModel', key: :author_id
  one_to_many :blogs, class: 'BlogModel', key: :owner_id

  one_to_many :administered_blogs, class: 'BlogModel', key: :administrator_id

  many_to_many :commented_posts, class: 'PostModel',
    join_table: 'comments', join_model: 'CommentModel',
    through: [:comments, :post]

  many_to_one :main_blog, class: 'BlogModel', key: :main_blog_id
end

class PostModel < Sequel::Model(:posts)
  include Praxis::Mapper::SequelCompat

  repository_name :sequel

  many_to_one :author, class: 'UserModel'
  one_to_many :comments, class: 'CommentModel'
end

class CommentModel < Sequel::Model(:comments)
  include Praxis::Mapper::SequelCompat

  repository_name :sequel

  set_primary_key [:author_id, :post_id]

  many_to_one :author, class: 'UserModel'
  many_to_one :post, class: 'PostModel'
end


class CompositeIdSequelModel < Sequel::Model(:composite_ids)
  include Praxis::Mapper::SequelCompat

  repository_name :sequel

  set_primary_key [:id, :type]

  one_to_many :others,
    class: 'OtherSequelModel',
    key: [:composite_id, :composite_type]
end

class OtherSequelModel < Sequel::Model(:others)
  include Praxis::Mapper::SequelCompat

  repository_name :sequel

  many_to_one :composite,
    class: 'CompositeIdSequelModel',
    key: [:composite_id, :composite_type]
end
