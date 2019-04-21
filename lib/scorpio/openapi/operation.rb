module Scorpio
  module OpenAPI
    # An OpenAPI operation
    #
    # Scorpio::OpenAPI::Operation is a module common to V2 and V3 operations.
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

        attr_writer :faraday_builder
        def faraday_builder
          return @faraday_builder if instance_variable_defined?(:@faraday_builder)
          openapi_document.faraday_builder
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

      # @return [Boolean] v3?
      def v3?
        is_a?(V3::Operation)
      end

      # @return [Boolean] v2?
      def v2?
        is_a?(V2::Operation)
      end

      # @return [Scorpio::OpenAPI::Document] the document whence this operation came
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

      # @return [Addressable::Template] the path as an Addressable::Template
      def path_template
        return @path_template if instance_variable_defined?(:@path_template)
        @path_template = Addressable::Template.new(path)
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

      def build_request(*a, &b)
        request = Scorpio::Request.new(self, *a, &b)
      end

      def run_ur(*a, &b)
        build_request(*a, &b).run_ur
      end

      def run(*a, &b)
        build_request(*a, &b).run
      end
    end

    module V3
      raise(Bug) unless const_defined?(:Operation)

      # Describes a single API operation on a path.
      #
      # https://github.com/OAI/OpenAPI-Specification/blob/master/versions/3.0.2.md#operationObject
      class Operation
        module Configurables
          def scheme
            # not applicable; for OpenAPI v3, scheme is specified by servers.
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
            if requestBody && requestBody['content']
              Request.best_media_type(requestBody['content'].keys)
            else
              openapi_document.request_media_type
            end
          end
        end
        include Configurables

        def request_schema(media_type: self.request_media_type)
          # TODO typechecking on requestBody & children
          requestBody &&
            requestBody['content'] &&
            requestBody['content'][media_type] &&
            requestBody['content'][media_type]['schema'] &&
            requestBody['content'][media_type]['schema'].deref
        end

        def request_schemas
          if requestBody && requestBody['content']
            # oamt is for Scorpio::OpenAPI::V3::MediaType
            requestBody['content'].values.map { |oamt| oamt['schema'] }.compact.map(&:deref)
          end
        end

        # @return JSI::Schema
        def response_schema(status: , media_type: )
          status = status.to_s if status.is_a?(Numeric)
          if self.responses
            # Scorpio::OpenAPI::V3::Response
            _, oa_response = self.responses.detect { |k, v| k.to_s == status }
            oa_response ||= self.responses['default']
          end
          oa_media_types = oa_response ? oa_response['content'] : nil # Scorpio::OpenAPI::V3::MediaTypes
          oa_media_type = oa_media_types ? oa_media_types[media_type] : nil # Scorpio::OpenAPI::V3::MediaType
          oa_schema = oa_media_type ? oa_media_type['schema'] : nil # Scorpio::OpenAPI::V3::Schema
          oa_schema ? JSI::Schema.new(oa_schema) : nil
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
            if key?('consumes')
              Request.best_media_type(consumes)
            else
              openapi_document.request_media_type
            end
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
            raise(Bug, "multiple body parameters on operation #{operation.pretty_inspect.chomp}") # TODO BLAME
          end
        end

        def request_schema(media_type: nil)
          if body_parameter && body_parameter['schema']
            JSI::Schema.new(body_parameter['schema'])
          else
            nil
          end
        end

        def request_schemas
          request_schema ? [request_schema] : []
        end

        # @return JSI::Schema
        def response_schema(status: , media_type: nil)
          status = status.to_s if status.is_a?(Numeric)
          if self.responses
            # Scorpio::OpenAPI::V2::Response
            _, oa_response = self.responses.detect { |k, v| k.to_s == status }
            oa_response ||= self.responses['default']
          end
          oa_response_schema = oa_response ? oa_response['schema'] : nil # Scorpio::OpenAPI::V2::Schema
          oa_response_schema ? JSI::Schema.new(oa_response_schema) : nil
        end
      end
    end
  end
end
