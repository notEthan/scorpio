module Scorpio
  module OpenAPI
    module Operation
      module Configurables
        attr_writer :base_url
        def base_url(scheme: self.scheme, server: self.server, server_variables: self.server_variables)
          return @base_url if instance_variable_defined?(:@base_url)
          openapi_document.base_url(scheme: scheme, server: server, server_variables: server_variables)
        end

        attr_writer :request_headers
        def request_headers
          return @request_headers if instance_variable_defined?(:@request_headers)
          openapi_document.request_headers
        end

        attr_writer :user_agent
        def user_agent
          return @user_agent if instance_variable_defined?(:@user_agent)
          openapi_document.user_agent
        end

        attr_writer :faraday_request_middleware
        def faraday_request_middleware
          return @faraday_request_middleware if instance_variable_defined?(:@faraday_request_middleware)
          openapi_document.faraday_request_middleware
        end

        attr_writer :faraday_response_middleware
        def faraday_response_middleware
          return @faraday_response_middleware if instance_variable_defined?(:@faraday_response_middleware)
          openapi_document.faraday_response_middleware
        end

        attr_writer :faraday_adapter
        def faraday_adapter
          return @faraday_adapter if instance_variable_defined?(:@faraday_adapter)
          openapi_document.faraday_adapter
        end

        attr_writer :logger
        def logger
          return @logger if instance_variable_defined?(:@logger)
          openapi_document.logger
        end
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
          def scheme
            nil
          end

          attr_writer :server
          def server
            return @server if instance_variable_defined?(:@server)
            openapi_document.server
          end

          attr_writer :server_variables
          def server_variables
            return @server_variables if instance_variable_defined?(:@server_variables)
            openapi_document.server_variables
          end

          attr_writer :request_media_type
          def request_media_type
            return @request_media_type if instance_variable_defined?(:@request_media_type)
            if requestBody && requestBody['content'] && requestBody['content'].keys.size == 1
              requestBody['content'].keys.first
            elsif openapi_document.request_media_type
              openapi_document.request_media_type
            end
          end
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
          attr_writer :scheme
          def scheme
            return @scheme if instance_variable_defined?(:@scheme)
            openapi_document.scheme
          end
          def server
            nil
          end
          def server_variables
            nil
          end

          attr_writer :request_media_type
          def request_media_type
            return @request_media_type if instance_variable_defined?(:@request_media_type)
            openapi_document.request_media_type
          end
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
