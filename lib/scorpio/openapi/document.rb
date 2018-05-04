module Scorpio
  module OpenAPI
    module Document
      module Configurables
      end
      include Configurables
    end

    module V3
      raise(Bug) unless const_defined?(:Document)
      class Document
        module Configurables
          attr_writer :base_url
          def base_url
            return @base_url if instance_variable_defined?(:@base_url)
            if servers.size == 1
              servers.first.url
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
