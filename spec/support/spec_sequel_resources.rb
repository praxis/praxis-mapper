class BlogResource < BaseResource
  property :display_name, dependencies: [:name]
  property :owner_email, dependencies: ['owner.email']
  property :owner_full_name, dependencies: ['owner.full_name']
  property :everything, dependencies: [:*]
  property :everything_from_owner, dependencies: ['owner.*']

  model BlogModel

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

  def full_name
    "#{first_name} #{last_name}"
  end
  property :full_name, dependencies: [:first_name, :last_name]

  def blogs_summary
    {
      href: "www.foo.com/#{self.id}",
      size: blogs.size
    }
  end

  property :blogs_summary, dependencies: [:id, :blogs]
end
