module Scorpio
  module OpenAPI
    module Operation
      module Configurables
      end
      include Configurables

      def openapi_document
        parents.detect { |p| p.is_a?(Scorpio::OpenAPI::Document) }
      end

      def path
        return @path if instance_variable_defined?(:@path)
        @path = begin
          parent_is_pathitem = parent.is_a?(Scorpio::OpenAPI::V2::PathItem) || parent.is_a?(Scorpio::OpenAPI::V3::PathItem)
          parent_parent_is_paths = parent.parent.is_a?(Scorpio::OpenAPI::V2::Paths) || parent.parent.is_a?(Scorpio::OpenAPI::V3::Paths)
          if parent_is_pathitem && parent_parent_is_paths
            parent.instance.path.last
          end
        end
      end

      def http_method
        return @http_method if instance_variable_defined?(:@http_method)
        @http_method = begin
          parent_is_pathitem = parent.is_a?(Scorpio::OpenAPI::V2::PathItem) || parent.is_a?(Scorpio::OpenAPI::V3::PathItem)
          if parent_is_pathitem
            instance.path.last
          end
        end
      end
    end

    module V3
      raise(Bug) unless const_defined?(:Operation)
      class Operation
        module Configurables
        end
        include Configurables

        def request_schemas
          if requestBody && requestBody['content']
            # oamt is for Scorpio::OpenAPI::V3::MediaType
            requestBody['content'].values.map { |oamt| oamt['schema'] }.compact.map(&:deref)
          end
        end
      end
    end
    module V2
      raise(Bug) unless const_defined?(:Operation)
      class Operation
        module Configurables
        end
        include Configurables

        # there should only be one body parameter; this returns it
        def body_parameter
          body_parameters = (parameters || []).select { |parameter| parameter['in'] == 'body' }
          if body_parameters.size == 0
            nil
          elsif body_parameters.size == 1
            body_parameters.first
          else
            raise(Bug) # TODO BLAME
          end
        end

        def request_schema
          if body_parameter && body_parameter['schema']
            JSI::Schema.new(body_parameter['schema'])
          end
        end

        def request_schemas
          [request_schema]
        end
      end
    end
  end
end
