# frozen_string_literal: true

module Scorpio
  module OpenAPI
    # A document that defines or describes an API.
    # An OpenAPI description document uses and conforms to the OpenAPI Specification.
    #
    # Scorpio::OpenAPI::Document is a module common to V2 and V3 documents.
    module Document
      class << self
        # takes a document, generally a Hash, and returns a Scorpio OpenAPI Document
        # instantiating it.
        #
        # @param instance [#to_hash] the document to represent as a Scorpio OpenAPI Document
        # @return [JSI::Base + Scorpio::OpenAPI::Document]
        def new_document(instance, **new_param)
          if instance.is_a?(Scorpio::OpenAPI::Document)
            instance
          elsif instance.is_a?(JSI::Base)
            raise(TypeError, -"instance is unexpected JSI type: #{instance.class.inspect}")
          elsif instance.respond_to?(:to_hash)
            if (instance['swagger'].is_a?(String) && instance['swagger'] =~ /\A2(\.|\z)/) || instance['swagger'] == 2
              Scorpio::OpenAPI::V2::Document.new_jsi(instance, **new_param)
            elsif (instance['openapi'].is_a?(String) && instance['openapi'] =~ /\A3\.0(\.|\z)/) || instance['openapi'] == 3.0
              Scorpio::OpenAPI::V3_0::Document.new_jsi(instance, **new_param)
            elsif (instance['openapi'].is_a?(String) && instance['openapi'] =~ /\A3\.1(\.|\z)/) || instance['openapi'] == 3.1
              Scorpio::OpenAPI::V3_1.new_document(instance, **new_param)
            elsif (instance['openapi'].is_a?(String) && instance['openapi'] =~ /\A3\.2(\.|\z)/) || instance['openapi'] == 3.2
              Scorpio::OpenAPI::V3_2.new_document(instance, **new_param)
            elsif instance['kind'] == 'discovery#restDescription'
              Scorpio::Google::RestDescription.new_jsi(instance, register: true, **new_param)
            else
              raise(ArgumentError, "instance does not look like a recognized openapi document")
            end
          else
            raise(TypeError, "instance does not look like a hash (json object)")
          end
        end

        # @deprecated after v0.8.0. use `new_document`.
        def from_instance(instance, **kw)
          Scorpio.new_document(instance, **kw)
        end

        # This is pretty much: `document_schema_module.with_dynamic_scope_from(JSI.registry.find(dialect_id))`
        #
        # However, this also supports a dialect whose meta-schema isn't aware of dynamic scope and doesn't
        # have a `$dynamicAnchor: "meta"`, e.g. `jsonSchemaDialect: "http://json-schema.org/draft-07/schema"`.
        #
        # A schema like {OpenAPI::V3_1::Ext::ExtDocument} exists to `$ref` to
        # {OpenAPI::V3_1::Unscoped::Document} with anchor `meta` in dynamic scope, with the
        # `$dynamicAnchor: "meta"` schema `$ref`ing to {OpenAPI::V3_1::Ext::MetaSchema}.
        # This method obviates the need for such a schema, directly applying dynamic scope.
        #
        # @api private
        # @param document_schema_module [JSI::SchemaModule]
        # @param dialect_id [#to_str]
        # @return [JSI::SchemaModule]
        def document_schema_module_with_meta(document_schema_module, dialect_id)
          metaschema = JSI.registry.find(dialect_id)
          dynamic_anchor_map = metaschema.jsi_next_schema_dynamic_anchor_map
          unless dynamic_anchor_map.key?('meta')
            # hax: pretend that the identified meta-schema has `$dynamicAnchor: "meta"`.
            # this enables e.g. `jsonSchemaDialect: "http://json-schema.org/draft-07/schema"` to work.
            # this is non-API JSI internals.
            dynamic_anchor_map = dynamic_anchor_map.merge({
              'meta' => [metaschema, [].freeze].freeze,
            }).freeze
          end
          document_schema_module.schema.jsi_with_schema_dynamic_anchor_map(dynamic_anchor_map).jsi_schema_module
        end
      end

      module Descendent
        # @return [Scorpio::OpenAPI::Document]
        def openapi_document
          jsi_ancestor_nodes.detect { |n| n.is_a?(OpenAPI::Document) } || raise(Error, -"not inside an OpenAPI document (#{inspect})")
        end
      end

      # Configurable attributes set on a document are inherited as configurable attributes
      # of each operation of the document (via {OpenAPI::Operation::Configurables})
      # and each request from an operation of the document (via {Request::Configurables}).
      module Configurables
        attr_writer(:scheme)
        # see {Request::Configurables#scheme}
        def scheme
          nil # overridden for v2
        end

        attr_writer(:server)
        # see {Request::Configurables#server}
        def server
          nil # overridden for v3
        end

        attr_writer(:server_variables)
        # see {Request::Configurables#server_variables}
        def server_variables
          nil # overridden for v3
        end

        attr_writer(:base_url)
        # see {Request::Configurables#base_url}
        def base_url(scheme: self.scheme, server: self.server, server_variables: self.server_variables)
          fail(NotImplementedError) # overridden
        end

        attr_writer(:request_media_type)
        # see {Request::Configurables#media_type}
        def request_media_type
          fail(NotImplementedError) # overridden
        end

        attr_writer :request_headers
        # see {Request::Configurables#headers}
        def request_headers
          return @request_headers if instance_variable_defined?(:@request_headers)
          {}.freeze
        end

        attr_writer :user_agent
        # see {Request::Configurables#user_agent}
        def user_agent
          return @user_agent if instance_variable_defined?(:@user_agent)
          Request::DEFAULT_USER_AGENT
        end

        attr_writer(:accept)
        # see {Request::Configurables#accept}
        def accept
          return @accept if instance_variable_defined?(:@accept)
          nil
        end

        attr_writer(:authorization)
        # see {Request::Configurables#authorization}
        def authorization
          return @authorization if instance_variable_defined?(:@authorization)
          nil
        end

        attr_writer :faraday_builder
        # see {Request::Configurables#faraday_builder}
        def faraday_builder
          return @faraday_builder if instance_variable_defined?(:@faraday_builder)
          nil
        end

        attr_writer :faraday_adapter
        # see {Request::Configurables#faraday_adapter}
        def faraday_adapter
          return @faraday_adapter if instance_variable_defined?(:@faraday_adapter)
          Faraday.default_adapter
        end

        attr_writer :logger
        # see {Request::Configurables#logger}
        def logger
          return @logger if instance_variable_defined?(:@logger)
          (Object.const_defined?(:Rails) && ::Rails.respond_to?(:logger) ? ::Rails.logger : nil)
        end
      end
      include Configurables

      def v2?
        is_a?(OpenAPI::V2::Document)
      end

      def v3?
        is_a?(OpenAPI::Document::V3Methods)
      end

      def operations
        return @operations if instance_variable_defined?(:@operations)
        @operations = OperationsScope.new(each_operation)
      end

      def each_operation(&block)
        return(to_enum(__method__)) unless block

        paths.each do |path, path_item|
          path_item.each do |http_method, operation|
            if operation.is_a?(Scorpio::OpenAPI::Operation)
              yield(operation)
            end
          end
          (path_item['additionalOperations'] || {}).each_value(&block) # only OAS v3.2+
        end
      end

      def title
        info && info.title
      end
    end

    # an OAD with a `$self` property that indicates its resource URI
    module Document::SelfURI
      # overrides JSI::Base#jsi_each_resource_uri_compute.
      # this is more into JSI internals than I prefer but currently this is the way to accomplish this.
      private def jsi_each_resource_uri_compute
        if respond_to?(:to_hash) && key?('$self')
          yield jsi_base_uri ? jsi_base_uri.join(jsi_node_content['$self']) : JSI::URI[jsi_node_content['$self']]
        end
        super
      end
    end

    module Document
      module V3Methods
          # @private (doc on Configurables)
          def server
            return @server if instance_variable_defined?(:@server)
            if servers.respond_to?(:to_ary) && servers.size == 1
              servers.first
            else
              raise(ConfigError, "configuration required: server (see https://rubydoc.info/gems/scorpio/Scorpio/Request/Configurables#server-instance_method )")
            end
          end

          # @private (doc on Configurables)
          def server_variables
            return @server_variables if instance_variable_defined?(:@server_variables)
            {}.freeze
          end

          # @private (doc on Configurables)
          def base_url(scheme: nil, server: self.server, server_variables: self.server_variables)
            return @base_url if instance_variable_defined?(:@base_url)
            server.expanded_url(server_variables)
          end

          # @private (doc on Configurables)
          attr_reader(:request_media_type)

        include(OpenAPI::Document)
      end
    end

    module Document
      module V2Methods
          # @private (doc on Configurables)
          def scheme
            return @scheme if instance_variable_defined?(:@scheme)
            if schemes.nil?
              'https'
            elsif schemes.respond_to?(:to_ary)
              # prefer https, then http, then anything else since we probably don't support.
              schemes.sort_by { |s| ['https', 'http'].index(s) || (1.0 / 0) }.first
            end
          end

          # @private (doc on Configurables)
          def base_url(scheme: self.scheme, server: nil, server_variables: nil)
            return @base_url if instance_variable_defined?(:@base_url)
            if host && scheme
              Addressable::URI.new(
                scheme: scheme,
                host: host,
                path: basePath,
              ).freeze
            else
              raise(ConfigError, "configuration required: base_url (see https://rubydoc.info/gems/scorpio/Scorpio/Request/Configurables#base_url-instance_method )")
            end
          end

          # @private (doc on Configurables)
          def request_media_type
            return @request_media_type if instance_variable_defined?(:@request_media_type)
            if consumes.respond_to?(:to_ary)
              Request.best_media_type(consumes)
            else
              nil
            end
          end

        include(OpenAPI::Document)
      end
    end
  end
end
