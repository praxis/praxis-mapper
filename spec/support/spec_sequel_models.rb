
#Sequel::Model.db = Sequel.mock
#Sequel::Model.db.columns = [:id]

DB = Sequel.sqlite
DB.create_table! :users do
  primary_key :id

  String :name
end

DB.create_table! :posts do
  primary_key :id
  Integer :author_id

  String :title
end

DB.create_table! :comment do
  primary_key :id
  Integer :author_id
  Integer :post_id


  String :body
end

class UserModel < Sequel::Model(:users)
  include Praxis::Mapper::SequelCompat

  one_to_many :posts, class: 'PostModel'
end

class PostModel < Sequel::Model(:posts) 
  include Praxis::Mapper::SequelCompat

  many_to_one :author, class: 'UserModel'
  one_to_many :comments, class: 'CommentModel'
end

class CommentModel < Sequel::Model(:comments)
  include Praxis::Mapper::SequelCompat
  
  many_to_one :author, class: 'UserModel'
  many_to_one :post, class: 'PostModel'
end
