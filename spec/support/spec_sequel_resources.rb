class BlogResource < BaseResource
  property :display_name, dependencies: [:name]
  property :owner_email, dependencies: ['owner.email']
  property :owner_full_name, dependencies: ['owner.full_name']
  property :everything, dependencies: [:*]
  property :everything_from_owner, dependencies: ['owner.*']
  property :kind, dependencies: nil

  model BlogModel

  def kind
    self.class.name.demodulize
  end

  def display_name
    self.name
  end

  def owner_email
    self.owner.email
  end

  def owner_full_name
    self.owner.full_name
  end

  def everything
    'everything'
  end

  def everything_from_owner
    'everything_from_owner'
  end

end

class UserResource < BaseResource
  model UserModel

  property :full_name, dependencies: [:first_name, :last_name]
  property :blogs_summary, dependencies: [:id, :blogs]

  property :recent_posts, dependencies: ['posts.created_at'],
    through: [:posts]


  def full_name
    "#{first_name} #{last_name}"
  end

  def blogs_summary
    {
      href: "www.foo.com/#{self.id}",
      size: blogs.size
    }
  end

  def recent_posts
    posts.sort_by(&:created_at).reverse[2]
  end

end

class CommentResource < BaseResource
  model CommentModel
end

class PostResource < BaseResource
  model PostModel

  property :slug, dependencies: [:slug, :title]

  # generate default slug from title if one wasn't set in the db
  def slug
    return record.slug if record.slug
    record.title.gsub(" ", "-").downcase
  end

end
