# frozen_string_literal: true

module Scorpio
  module OpenAPI
    class Error < StandardError
    end
    # an error in the semantics of an openapi document. for example, an Operation with
    # two body parameters (in v2, not possible in v3) is a SemanticError. an Operation
    # with more than one parameter with the same 'name' and 'in' properties would also be
    # a SemanticError.
    #
    # an instance of a SemanticError may or may not correspond to a validation error of
    # an OpenAPI document against the OpenAPI schema.
    class SemanticError < Error
    end

    autoload :Operation, 'scorpio/openapi/operation'
    autoload :Document, 'scorpio/openapi/document'
    autoload :Reference, 'scorpio/openapi/reference'
    autoload :Tag, 'scorpio/openapi/tag'
    autoload(:Tags, 'scorpio/openapi/tag')
    autoload(:Server, 'scorpio/openapi/server')
    autoload :OperationsScope, 'scorpio/openapi/operations_scope'

    module Paths
    end

    module PathItem
    end

    module SecurityScheme
      include(Document::Descendent)

      # @return [Enumerable<OpenAPI::Operation>]
      def operations
        openapi_document.operations.select do |op|
          op.security.respond_to?(:to_ary) && op.security.any? { |sr| sr.each_key.include?(propertyName) }
        end
      end

      def propertyName
        jsi_ptr.tokens.last
      end
    end

    autoload(:V2, 'scorpio/openapi/v2')
    autoload(:V3, 'scorpio/openapi/v3_0')
    autoload(:V3_0, 'scorpio/openapi/v3_0')
    autoload(:V3_1, 'scorpio/openapi/v3_1')
  end
end
