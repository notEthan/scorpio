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

        def path
          @path ||= if parent.is_a?(Scorpio::OpenAPI::V2::PathItem) && parent.parent.is_a?(Scorpio::OpenAPI::V2::Paths)
            parent.instance.path.last
          end
        end

        def http_method
          @http_method ||= if parent.is_a?(Scorpio::OpenAPI::V2::PathItem)
            instance.path.last
          end
        end

        # there should only be one body parameter; this returns it
        def body_parameter
          (parameters || []).detect do |parameter|
            parameter['in'] == 'body'
          end
        end

        def request_schema
          if body_parameter && body_parameter['schema']
            JSI::Schema.new(body_parameter['schema'])
          end
        end
      end
    end
  end
end
