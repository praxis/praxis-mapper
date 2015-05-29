
#Sequel::Model.db = Sequel.mock
#Sequel::Model.db.columns = [:id]

DB = Sequel.sqlite
DB.create_table! :users do
  primary_key :id

  String :name
  String :email
end

DB.create_table! :posts do
  primary_key :id
  Integer :author_id

  String :title
  String :body
end

DB.create_table! :comments do

  Integer :author_id
  Integer :post_id

  String :body

  primary_key [:author_id, :post_id]
end

Praxis::Mapper::ConnectionManager.setup do
  repository(:sequel, query: Praxis::Mapper::Query::Sequel) do
    DB
  end
end

class UserModel < Sequel::Model(:users)
  include Praxis::Mapper::SequelCompat

  repository_name :sequel

  one_to_many :posts, class: 'PostModel'
  one_to_many :comments, class: 'CommentModel'

  many_to_many :commented_posts, class: 'PostModel',
    join_table: 'comments', join_model: 'CommentModel'
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
