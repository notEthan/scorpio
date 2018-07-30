module Scorpio
  module OpenAPI
    module Document
      module Configurables
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
