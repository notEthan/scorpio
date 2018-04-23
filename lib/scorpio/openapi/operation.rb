module Scorpio
  module OpenAPI
    module Operation
    end

    module V3
      raise(Bug) unless const_defined?(:Operation)
      class Operation
      end
    end
    module V2
      raise(Bug) unless const_defined?(:Operation)
      class Operation
      end
    end
  end
end
