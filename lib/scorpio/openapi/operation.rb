module Scorpio
  module OpenAPI
    module Operation
      module Configurables
      end
      include Configurables
    end

    module V3
      raise(Bug) unless const_defined?(:Operation)
      class Operation
        module Configurables
        end
        include Configurables
      end
    end
    module V2
      raise(Bug) unless const_defined?(:Operation)
      class Operation
        module Configurables
        end
        include Configurables
      end
    end
  end
end
