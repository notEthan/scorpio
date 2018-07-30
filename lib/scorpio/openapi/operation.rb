module Scorpio
  module OpenAPI
    module Operation
      module Configurables
      end
      include Configurables

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
