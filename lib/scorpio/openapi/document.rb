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
        def from_instance(instance, **new_param)
          if instance.is_a?(Scorpio::OpenAPI::Document)
            instance
          elsif instance.is_a?(JSI::Base)
            raise(TypeError, "instance is unexpected JSI type: #{instance.class.inspect}")
          elsif instance.respond_to?(:to_hash)
            if (instance['swagger'].is_a?(String) && instance['swagger'] =~ /\A2(\.|\z)/) || instance['swagger'] == 2
              Scorpio::OpenAPI::V2::Document.new_jsi(instance, **new_param)
            elsif (instance['openapi'].is_a?(String) && instance['openapi'] =~ /\A3\.0(\.|\z)/) || instance['openapi'] == 3.0
              Scorpio::OpenAPI::V3_0::Document.new_jsi(instance, **new_param)
            elsif instance['kind'] == 'discovery#restDescription'
              Scorpio::Google::RestDescription.new_jsi(instance, register: true, **new_param)
            else
              raise(ArgumentError, "instance does not look like a recognized openapi document")
            end
          else
            raise(TypeError, "instance does not look like a hash (json object)")
          end
        end
      end

      module Descendent
        # @return [Scorpio::OpenAPI::Document]
        def openapi_document
          jsi_ancestor_nodes.detect { |n| n.is_a?(OpenAPI::Document) } || raise(Error, "not inside an OpenAPI document (#{inspect})")
        end
      end

      module Configurables
        attr_writer :request_headers
        def request_headers
          return @request_headers if instance_variable_defined?(:@request_headers)
          {}.freeze
        end

        attr_writer :user_agent
        def user_agent
          return @user_agent if instance_variable_defined?(:@user_agent)
          "Scorpio/#{Scorpio::VERSION} (https://github.com/notEthan/scorpio) Faraday/#{Faraday::VERSION} Ruby/#{RUBY_VERSION}"
        end

        attr_writer :faraday_builder
        def faraday_builder
          return @faraday_builder if instance_variable_defined?(:@faraday_builder)
          nil
        end

        attr_writer :faraday_adapter
        def faraday_adapter
          return @faraday_adapter if instance_variable_defined?(:@faraday_adapter)
          [Faraday.default_adapter].freeze
        end

        attr_writer :logger
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
        is_a?(OpenAPI::V3_0::Document)
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
        end
      end

      def title
        info && info.title
      end
    end

    module Document
      module V3Methods
        module Configurables
          def scheme
            nil
          end
          attr_writer :server
          def server
            return @server if instance_variable_defined?(:@server)
            if servers.respond_to?(:to_ary) && servers.size == 1
              servers.first
            else
              nil
            end
          end
          attr_writer :server_variables
          def server_variables
            return @server_variables if instance_variable_defined?(:@server_variables)
            {}.freeze
          end
          attr_writer :base_url
          def base_url(scheme: nil, server: self.server, server_variables: self.server_variables)
            return @base_url if instance_variable_defined?(:@base_url)
            if server
              server.expanded_url(server_variables)
            end
          end

          attr_writer :request_media_type
          def request_media_type
            return @request_media_type if instance_variable_defined?(:@request_media_type)
            nil
          end
        end
        include Configurables
        include(OpenAPI::Document)
      end
    end

    module Document
      module V2Methods
        module Configurables
          attr_writer :scheme
          def scheme
            return @scheme if instance_variable_defined?(:@scheme)
            if schemes.nil?
              'https'
            elsif schemes.respond_to?(:to_ary)
              # prefer https, then http, then anything else since we probably don't support.
              schemes.sort_by { |s| ['https', 'http'].index(s) || (1.0 / 0) }.first
            end
          end

          def server
            nil
          end
          def server_variables
            nil
          end

          attr_writer :base_url
          # the base url to which paths are appended.
          # by default this looks at the openapi document's schemes, picking https or http first.
          # it looks at the openapi_document's host and basePath.
          def base_url(scheme: self.scheme, server: nil, server_variables: nil)
            return @base_url if instance_variable_defined?(:@base_url)
            if host && scheme
              Addressable::URI.new(
                scheme: scheme,
                host: host,
                path: basePath,
              ).freeze
            end
          end

          attr_writer :request_media_type
          def request_media_type
            return @request_media_type if instance_variable_defined?(:@request_media_type)
            if consumes.respond_to?(:to_ary)
              Request.best_media_type(consumes)
            else
              nil
            end
          end
        end
        include Configurables
        include(OpenAPI::Document)
      end
    end
  end
end
