module Scorpio
  module OpenAPI
    # A document that defines or describes an API.
    # An OpenAPI definition uses and conforms to the OpenAPI Specification.
    #
    # Scorpio::OpenAPI::Document is a module common to V2 and V3 documents.
    module Document
      class << self
        # takes a document, generally a Hash, and returns a Scorpio OpenAPI Document
        # instantiating it.
        #
        # @param instance [#to_hash] the document to represent as a Scorpio OpenAPI Document
        # @return [Scorpio::OpenAPI::V2::Document, Scorpio::OpenAPI::V3::Document]
        def from_instance(instance)
          if instance.is_a?(Hash)
            instance = JSI::JSON::Node.new_doc(instance)
          end
          if instance.is_a?(JSI::JSON::Node)
            if instance['swagger'] =~ /\A2(\.|\z)/
              instance = Scorpio::OpenAPI::V2::Document.new(instance)
            elsif instance['openapi'] =~ /\A3(\.|\z)/
              instance = Scorpio::OpenAPI::V3::Document.new(instance)
            else
              raise(ArgumentError, "instance does not look like a recognized openapi document")
            end
          end
          if instance.is_a?(Scorpio::OpenAPI::Document)
            instance
          elsif instance.is_a?(JSI::Base)
            raise(TypeError, "instance is unexpected JSI type: #{instance.class.inspect}")
          elsif instance.respond_to?(:to_hash)
            from_instance(instance.to_hash)
          else
            raise(TypeError, "instance does not look like a hash (json object)")
          end
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
          -> (_) { }
        end

        attr_writer :faraday_adapter
        def faraday_adapter
          return @faraday_adapter if instance_variable_defined?(:@faraday_adapter)
          [Faraday.default_adapter]
        end

        attr_writer :logger
        def logger
          return @logger if instance_variable_defined?(:@logger)
          (Object.const_defined?(:Rails) && ::Rails.respond_to?(:logger) ? ::Rails.logger : nil)
        end
      end
      include Configurables

      def v2?
        is_a?(V2::Document)
      end

      def v3?
        is_a?(V3::Document)
      end

      def operations
        return @operations if instance_variable_defined?(:@operations)
        @operations = OperationsScope.new(self)
      end
    end

    module V3
      raise(Bug, 'const_defined? Scorpio::OpenAPI::V3::Document') unless const_defined?(:Document)

      # A document that defines or describes an API conforming to the OpenAPI Specification v3.
      #
      # https://github.com/OAI/OpenAPI-Specification/blob/master/versions/3.0.2.md#oasObject
      class Document
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
      end
    end

    module V2
      raise(Bug, 'const_defined? Scorpio::OpenAPI::V2::Document') unless const_defined?(:Document)

      # A document that defines or describes an API conforming to the OpenAPI Specification v2 (aka Swagger).
      #
      # The root document is known as the Swagger Object.
      class Document
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
              ).to_s
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
      end
    end
  end
end
