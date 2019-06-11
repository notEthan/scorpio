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

      def path_template_str
        return @path_template_str if instance_variable_defined?(:@path_template_str)
        @path_template_str = begin
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
        @path_template = Addressable::Template.new(path_template_str)
      end

      # @param base_url [#to_str] the base URL to which the path template is appended
      # @return [Addressable::Template] the URI template, consisting of the base_url
      #   concatenated with the path template
      def uri_template(base_url: self.base_url)
        unless base_url
          raise(ArgumentError, "no base_url has been specified for operation #{self}")
        end
        # we do not use Addressable::URI#join as the paths should just be concatenated, not resolved.
        # we use File.join just to deal with consecutive slashes.
        Addressable::Template.new(File.join(base_url, path_template_str))
      end

      # @return the HTTP method of this operation as indicated by the attribute name
      #   for this operation from the parent PathItem
      def http_method
        return @http_method if instance_variable_defined?(:@http_method)
        @http_method = begin
          parent_is_pathitem = parent.is_a?(Scorpio::OpenAPI::V2::PathItem) || parent.is_a?(Scorpio::OpenAPI::V3::PathItem)
          if parent_is_pathitem
            instance.path.last
          end
        end
      end

      # @return [String] a short identifier for this operation appropriate for an error message
      def human_id
        operationId || "path: #{path_template_str}, method: #{http_method}"
      end

      # @return [Scorpio::OpenAPI::V3::Response, Scorpio::OpenAPI::V2::Response]
      def oa_response(status: )
        status = status.to_s if status.is_a?(Numeric)
        if self.responses
          _, oa_response = self.responses.detect { |k, v| k.to_s == status }
          oa_response ||= self.responses['default']
        end
        oa_response
      end

      # this method is not intended to be API-stable at the moment.
      #
      # @return [#to_ary<#to_h>] the parameters specified for this operation, plus any others
      #   scorpio considers to be parameters
      def inferred_parameters
        parameters = self.parameters ? self.parameters.to_a.dup : []
        path_template.variables.each do |var|
          unless parameters.any? { |p| p['in'] == 'path' && p['name'] == var }
            # we could instantiate this as a V2::Parameter or a V3::Parameter
            # or a ParameterWithContentInPath or whatever. but I can't be bothered.
            parameters << {
              'name' => var,
              'in' => 'path',
              'required' => true,
              'type' => 'string',
            }
          end
        end
        parameters
      end

      # @return [Module] a module with accessor methods for unambiguously named parameters of this operation.
      def request_accessor_module
        return @request_accessor_module if instance_variable_defined?(:@request_accessor_module)
        @request_accessor_module = begin
          params_by_name = inferred_parameters.group_by { |p| p['name'] }
          Module.new do
            instance_method_modules = [Request, Request::Configurables]
            instance_method_names = instance_method_modules.map do |mod|
              (mod.instance_methods + mod.private_instance_methods).map(&:to_s)
            end.inject(Set.new, &:|)
            params_by_name.each do |name, params|
              next if instance_method_names.include?(name)
              if params.size == 1
                param = params.first
                define_method("#{name}=") { |value| set_param_from(param['in'], param['name'], value) }
                define_method(name) { get_param_from(param['in'], param['name']) }
              end
            end
          end
        end
      end

      # @param a, b are passed to Scorpio::Request#initialize
      # @return [Scorpio::Request]
      def build_request(*a, &b)
        Scorpio::Request.new(self, *a, &b)
      end

      # @param a, b are passed to Scorpio::Request#initialize
      # @return [Scorpio::Ur] response ur
      def run_ur(*a, &b)
        build_request(*a, &b).run_ur
      end

      # @param a, b are passed to Scorpio::Request#initialize
      # @return response body object
      def run(*a, &b)
        build_request(*a, &b).run
      end
    end

    module V3
      raise(Bug, 'const_defined? Scorpio::OpenAPI::V3::Operation') unless const_defined?(:Operation)

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

        # @return [JSI::Schema]
        def request_schema(media_type: self.request_media_type)
          # TODO typechecking on requestBody & children
          schema_object = requestBody &&
            requestBody['content'] &&
            requestBody['content'][media_type] &&
            requestBody['content'][media_type]['schema']
          schema_object ? JSI::Schema.from_object(schema_object) : nil
        end

        # @return [Array<JSI::Schema>]
        def request_schemas
          if requestBody && requestBody['content']
            # oamt is for Scorpio::OpenAPI::V3::MediaType
            oamts = requestBody['content'].values.select { |oamt| oamt.key?('schema') }
            oamts.map { |oamt| JSI::Schema.from_object(oamt['schema']) }
          else
            []
          end
        end

        # @return [JSI::Schema]
        def response_schema(status: , media_type: )
          oa_response = self.oa_response(status: status)
          oa_media_types = oa_response ? oa_response['content'] : nil # Scorpio::OpenAPI::V3::MediaTypes
          oa_media_type = oa_media_types ? oa_media_types[media_type] : nil # Scorpio::OpenAPI::V3::MediaType
          oa_schema = oa_media_type ? oa_media_type['schema'] : nil # Scorpio::OpenAPI::V3::Schema
          oa_schema ? JSI::Schema.new(oa_schema) : nil
        end
      end
    end
    module V2
      raise(Bug, 'const_defined? Scorpio::OpenAPI::V2::Operation') unless const_defined?(:Operation)
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
            # TODO blame
            raise(OpenAPI::SemanticError, "multiple body parameters on operation #{operation.pretty_inspect.chomp}")
          end
        end

        # @param media_type unused
        # @return [JSI::Schema] request schema for the given media_type
        def request_schema(media_type: nil)
          if body_parameter && body_parameter['schema']
            JSI::Schema.new(body_parameter['schema'])
          else
            nil
          end
        end

        # @return [Array<JSI::Schema>]
        def request_schemas
          request_schema ? [request_schema] : []
        end

        # @param status [Integer, String] response status
        # @param media_type unused
        # @return [JSI::Schema]
        def response_schema(status: , media_type: nil)
          oa_response = self.oa_response(status: status)
          oa_response_schema = oa_response ? oa_response['schema'] : nil # Scorpio::OpenAPI::V2::Schema
          oa_response_schema ? JSI::Schema.new(oa_response_schema) : nil
        end
      end
    end
  end
end
