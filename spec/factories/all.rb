FactoryBot.define do

  to_create { |i| i.save }

  factory :blog, class: BlogModel do
    name { /\w+/.gen }
    owner
  end

  factory :user, class: UserModel, aliases: [:author, :owner] do
    first_name { /[:first_name:]/.gen }
    last_name { /[:last_name]/.gen }
    email { /[:email:]/.gen }
  end

  factory :post, class: PostModel do
    title { /\w+/.gen }
    body  { /\w+/.gen }
    created_at { DateTime.now - rand(100) }
    author
  end

  factory :comment, class: CommentModel do
    author
    post
  end

  factory :composite, class: CompositeIdSequelModel do
    id { /\w+/.gen }
    type { /\w+/.gen }

    name  { /\w+/.gen }
  end

  factory :other, class: OtherSequelModel do
    composite
  end

end
