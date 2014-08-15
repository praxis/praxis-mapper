module Praxis::Mapper
  class ConfigHash < BasicObject

    attr_reader :hash

    def self.from(hash={},&block)
      self.new(hash,&block)
    end

    def initialize(hash={},&block)
      @hash = hash
      @block = block
    end

    def to_hash
      self.instance_eval(&@block)
      @hash
    end

    def method_missing(name, value, *rest, &block)
      if (existing = @hash[name])
        if block
          existing << [value, block]
        else
          existing << value
          rest.each do |v|
            existing << v
          end
        end
      else
        if rest.any?
          @hash[name] = [value] + rest
        else
          @hash[name] = value
        end
      end
    end

  end
end
