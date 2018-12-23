module Scorpio
  module OpenAPI
    module Document
    end

    module V3
      raise(Bug) unless const_defined?(:Document)
      class Document
      end
    end

    module V2
      raise(Bug) unless const_defined?(:Document)
      class Document
      end
    end
  end
end
