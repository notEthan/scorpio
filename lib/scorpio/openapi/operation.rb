# frozen_string_literal: true

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

      # openapi v3?
      # @return [Boolean]
      def v3?
        is_a?(OpenAPI::V3::Operation)
      end

      # openapi v2?
      # @return [Boolean]
      def v2?
        is_a?(OpenAPI::V2::Operation)
      end

      # the document whence this operation came
      # @return [Scorpio::OpenAPI::Document]
      def openapi_document
        jsi_parent_nodes.detect { |p| p.is_a?(Scorpio::OpenAPI::Document) }
      end

      # @return [String]
      def path_template_str
        return @path_template_str if instance_variable_defined?(:@path_template_str)
        raise(Bug) unless jsi_parent_node.is_a?(Scorpio::OpenAPI::V2::PathItem) || jsi_parent_node.is_a?(Scorpio::OpenAPI::V3::PathItem)
        raise(Bug) unless jsi_parent_node.jsi_parent_node.is_a?(Scorpio::OpenAPI::V2::Paths) || jsi_parent_node.jsi_parent_node.is_a?(Scorpio::OpenAPI::V3::Paths)
        @path_template_str = jsi_parent_node.jsi_ptr.tokens.last
      end

      # the path as an Addressable::Template
      # @return [Addressable::Template]
      def path_template
        return @path_template if instance_variable_defined?(:@path_template)
        @path_template = Addressable::Template.new(path_template_str)
      end

      # the URI template, consisting of the base_url concatenated with the path template
      # @param base_url [#to_str] the base URL to which the path template is appended
      # @return [Addressable::Template]
      def uri_template(base_url: self.base_url)
        unless base_url
          raise(ArgumentError, "no base_url has been specified for operation #{self}")
        end
        # we do not use Addressable::URI#join as the paths should just be concatenated, not resolved.
        # we use File.join just to deal with consecutive slashes.
        Addressable::Template.new(File.join(base_url, path_template_str))
      end

      # the HTTP method of this operation as indicated by the attribute name for this operation
      # from the parent PathItem
      # @return [String]
      def http_method
        return @http_method if instance_variable_defined?(:@http_method)
        raise(Bug) unless jsi_parent_node.is_a?(Scorpio::OpenAPI::V2::PathItem) || jsi_parent_node.is_a?(Scorpio::OpenAPI::V3::PathItem)
        @http_method = jsi_ptr.tokens.last
      end

      def get?
        'get'.casecmp?(http_method)
      end

      def put?
        'put'.casecmp?(http_method)
      end

      def post?
        'post'.casecmp?(http_method)
      end

      def delete?
        'delete'.casecmp?(http_method)
      end

      def options?
        'options'.casecmp?(http_method)
      end

      def head?
        'head'.casecmp?(http_method)
      end

      def patch?
        'patch'.casecmp?(http_method)
      end

      def trace?
        'trace'.casecmp?(http_method)
      end

      # @param tag_name [String]
      # @return [Boolean]
      def tagged?(tag_name)
        tags.respond_to?(:to_ary) && tags.include?(tag_name)
      end

      # a short identifier for this operation appropriate for an error message
      # @return [String]
      def human_id
        operationId || "path: #{path_template_str}, method: #{http_method}"
      end

      # @param status [String, Integer]
      # @return [Scorpio::OpenAPI::V3::Response, Scorpio::OpenAPI::V2::Response]
      def oa_response(status: )
        status = status.to_s if status.is_a?(Numeric)
        if responses
          _, oa_response = responses.detect { |k, v| k.to_s == status }
          oa_response ||= responses['default']
        end
        oa_response
      end

      # the parameters specified for this operation, plus any others scorpio considers to be parameters.
      #
      # @api private
      # @return [#to_ary<#to_h>]
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

      # a module with accessor methods for unambiguously named parameters of this operation.
      # @return [Module]
      def request_accessor_module
        return @request_accessor_module if instance_variable_defined?(:@request_accessor_module)
        @request_accessor_module = begin
          params_by_name = inferred_parameters.group_by { |p| p['name'] }
          Module.new do
            instance_method_modules = [Request]
            instance_method_names = instance_method_modules.map do |mod|
              (mod.instance_methods + mod.private_instance_methods).map(&:to_s)
            end.inject(Set.new, &:merge)
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

      # instantiates a {Scorpio::Request} for this operation.
      # parameters are all passed to {Scorpio::Request#initialize}.
      # @return [Scorpio::Request]
      def build_request(configuration = {}, &b)
        @request_class ||= Scorpio::Request.request_class_by_operation(self)
        @request_class.new(configuration, &b)
      end

      # runs a {Scorpio::Request} for this operation, returning a {Scorpio::Ur}.
      # parameters are all passed to {Scorpio::Request#initialize}.
      # @return [Scorpio::Ur] response ur
      def run_ur(configuration = {}, &b)
        build_request(configuration, &b).run_ur
      end

      # runs a {Scorpio::Request} for this operation - see {Scorpio::Request#run}.
      # parameters are all passed to {Scorpio::Request#initialize}.
      # @return response body object
      def run(configuration = {}, &b)
        build_request(configuration, &b).run
      end

      # Runs this operation with the given request config, and yields the resulting {Scorpio::Ur}.
      # If the response contains a `Link` header with a `next` link (and that link's URL
      # corresponds to this operation), this operation is run again to that link's URL, that
      # request's Ur yielded, and a `next` link in that response is followed.
      # This repeats until a response does not contain a `Link` header with a `next` link.
      #
      # @param configuration (see Scorpio::Request#initialize)
      # @yield [Scorpio::Ur]
      # @return [Enumerator, nil]
      def each_link_page(configuration = {}, &block)
        init_request = build_request(configuration)
        next_page = proc do |last_page_ur|
          nextlinks = last_page_ur.response.links.select { |link| link.rel?('next') }
          if nextlinks.size == 0
            # no next link; we are at the end
            nil
          elsif nextlinks.size == 1
            nextlink = nextlinks.first
            # we do not use Addressable::URI#join as the paths should just be concatenated, not resolved.
            # we use File.join just to deal with consecutive slashes.
            template = Addressable::Template.new(File.join(init_request.base_url, path_template_str))
            target_uri = nextlink.absolute_target_uri
            path_params = template.extract(target_uri.merge(query: nil))
            unless path_params
              raise("the URI of the link to the next page did not match the URI of this operation")
            end
            query_params = target_uri.query_values
            run_ur(
              path_params: path_params,
              query_params: query_params,
            )
          else
            # TODO better error class / context / message
            raise("response included multiple links with rel=next")
          end
        end
        init_request.each_page_ur(next_page: next_page, &block)
      end

      private

      def jsi_object_group_text
        [*super, http_method, path_template_str].freeze
      end
    end

    module Operation
      module V3Methods
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
        include(OpenAPI::Operation)

        # @return [JSI::Schema]
        def request_schema(media_type: self.request_media_type)
          # TODO typechecking on requestBody & children
          request_content = requestBody && requestBody['content']
          return nil unless request_content
          raise(ArgumentError, "please specify media_type for request_schema") unless media_type
          schema = request_content[media_type] && request_content[media_type]['schema']
          return nil unless schema
          JSI::Schema.ensure_schema(schema)
        end

        # @return [JSI::SchemaSet]
        def request_schemas
          JSI::SchemaSet.build do |schemas|
            if requestBody && requestBody['content']
              requestBody['content'].each_value do |oa_media_type|
                if oa_media_type['schema']
                  schemas << oa_media_type['schema']
                end
              end
            end
          end
        end

        # @return [JSI::Schema]
        def response_schema(status: , media_type: )
          oa_response = self.oa_response(status: status)
          oa_media_types = oa_response ? oa_response['content'] : nil # Scorpio::OpenAPI::V3::MediaTypes
          oa_media_type = oa_media_types ? oa_media_types[media_type] : nil # Scorpio::OpenAPI::V3::MediaType
          oa_schema = oa_media_type ? oa_media_type['schema'] : nil # Scorpio::OpenAPI::V3::Schema
          oa_schema ? JSI::Schema.ensure_schema(oa_schema) : nil
        end

        # @return [JSI::SchemaSet]
        def response_schemas
          JSI::SchemaSet.build do |schemas|
            if responses
              responses.each_value do |oa_response|
                if oa_response['content']
                  oa_response['content'].each_value do |oa_media_type|
                    if oa_media_type['schema']
                      schemas << oa_media_type['schema']
                    end
                  end
                end
              end
            end
          end
        end
      end
    end

    module Operation
      module V2Methods
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
        include(OpenAPI::Operation)

        # the body parameter
        # @return [#to_hash]
        # @raise [Scorpio::OpenAPI::SemanticError] if there's more than one body param
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

        # request schema for the given media_type
        # @param media_type unused
        # @return [JSI::Schema]
        def request_schema(media_type: nil)
          if body_parameter && body_parameter['schema']
            JSI::Schema.ensure_schema(body_parameter['schema'])
          else
            nil
          end
        end

        # @return [JSI::SchemaSet]
        def request_schemas
          request_schema ? JSI::SchemaSet[request_schema] : JSI::SchemaSet[]
        end

        # @param status [Integer, String] response status
        # @param media_type unused
        # @return [JSI::Schema]
        def response_schema(status: , media_type: nil)
          oa_response = self.oa_response(status: status)
          oa_response_schema = oa_response ? oa_response['schema'] : nil # Scorpio::OpenAPI::V2::Schema
          oa_response_schema ? JSI::Schema.ensure_schema(oa_response_schema) : nil
        end

        # @return [JSI::SchemaSet]
        def response_schemas
          JSI::SchemaSet.build do |schemas|
            if responses
              responses.each_value do |oa_response|
                if oa_response['schema']
                  schemas << oa_response['schema']
                end
              end
            end
          end
        end
      end
    end
  end
end
