# A test model with an example generator
class SimpleModel < Praxis::Mapper::Model
  def self.generate
    data = {
      :id => /\d{10}/.gen.to_i, 
      :name => /\w+/.gen, 
      :parent_id  => /\d{10}/.gen.to_i
    }

    self.new(data)
  end
end
