module Scorpio
  module OpenAPI
    module Document
      class << self
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
        attr_writer :user_agent
        def user_agent
          return @user_agent if instance_variable_defined?(:@user_agent)
          "Scorpio/#{Scorpio::VERSION} (https://github.com/notEthan/scorpio) Faraday/#{Faraday::VERSION} Ruby/#{RUBY_VERSION}"
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
      raise(Bug) unless const_defined?(:Document)
      class Document
        module Configurables
          attr_writer :base_url
          def base_url(server: nil, server_variables: {})
            return @base_url if instance_variable_defined?(:@base_url)
            server = servers.first if !server && servers.size == 1
            if server
              server.expanded_url(server_variables)
            end
          end
        end
        include Configurables
      end
    end

    module V2
      raise(Bug) unless const_defined?(:Document)
      class Document
        module Configurables
          attr_writer :base_url
          # the base url to which paths are appended.
          # by default this looks at the openapi document's schemes, picking https or http first.
          # it looks at the openapi_document's host and basePath.
          def base_url
            return @base_url if instance_variable_defined?(:@base_url)
            if schemes.nil?
              scheme = 'https'
            elsif schemes.respond_to?(:to_ary)
              # prefer https, then http, then anything else since we probably don't support.
              scheme = schemes.sort_by { |s| ['https', 'http'].index(s) || (1.0 / 0) }.first
            end
            if host && scheme
              Addressable::URI.new(
                scheme: scheme,
                host: host,
                path: basePath,
              ).to_s
            end
          end
        end
        include Configurables
      end
    end
  end
end
