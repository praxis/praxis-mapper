module Praxis::Mapper
  module Finalizable


    def self.extended(klass)
      klass.module_eval do
        @finalizable = Set.new
      end
    end

    def inherited(base)
      @finalizable << base
      base.instance_variable_set(:@finalizable, @finalizable)
      base.instance_variable_set(:@finalized, false)
    end

    def finalizable
      @finalizable
    end

    def finalized?
      @finalized
    end

    def _finalize!
      @finalized = true
    end

    def finalize! 
      self.finalizable.reject(&:finalized?).each do |klass|
        klass._finalize!
      end

      self.finalize! unless self.finalizable.all?(&:finalized?)
    end

  end
end
