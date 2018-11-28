module Scorpio
  module OpenAPI
    module Document
      module Configurables
      end
      include Configurables
    end

    module V3
      raise(Bug) unless const_defined?(:Document)
      class Document
        module Configurables
        end
        include Configurables
      end
    end

    module V2
      raise(Bug) unless const_defined?(:Document)
      class Document
        module Configurables
        end
        include Configurables
      end
    end
  end
end
