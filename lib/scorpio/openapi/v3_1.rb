# frozen_string_literal: true

module Scorpio
  module OpenAPI
    module V3_1
      def self.document_name_subschemas(document_schema_module, namespace)
        namespace.const_set(:Info,         document_schema_module.defs['info'])
        namespace.const_set(:Contact,       document_schema_module.defs['contact'])
        namespace.const_set(:License,        document_schema_module.defs['license'])
        namespace.const_set(:Server,          document_schema_module.defs['server'])
        namespace.const_set(:ServerVariable,   document_schema_module.defs['server-variable'])
        namespace.const_set(:Components,        document_schema_module.defs['components'])
        namespace.const_set(:Paths,              document_schema_module.defs['paths'])
        namespace.const_set(:PathItem,            document_schema_module.defs['path-item'])
        namespace.const_set(:Operation,            document_schema_module.defs['operation'])
        namespace.const_set(:ExternalDocumentation, document_schema_module.defs['external-documentation'])
        namespace.const_set(:Parameter,            document_schema_module.defs['parameter'])
        namespace.const_set(:ParameterOrReference, document_schema_module.defs['parameter-or-reference'])
        namespace.const_set(:RequestBody,         document_schema_module.defs['request-body'])
        namespace.const_set(:RequestBodyOrReference, document_schema_module.defs['request-body-or-reference'])
        namespace.const_set(:Content,            document_schema_module.defs['content'])
        namespace.const_set(:MediaType,         document_schema_module.defs['media-type'])
        namespace.const_set(:Encoding,         document_schema_module.defs['encoding'])
        namespace.const_set(:Responses,       document_schema_module.defs['responses'])
        namespace.const_set(:Response,       document_schema_module.defs['response'])
        namespace.const_set(:ResponseOrReference, document_schema_module.defs['response-or-reference'])
        namespace.const_set(:Callbacks,     document_schema_module.defs['callbacks'])
        namespace.const_set(:CallbacksOrReference, document_schema_module.defs['callbacks-or-reference'])
        namespace.const_set(:Example,      document_schema_module.defs['example'])
        namespace.const_set(:ExampleOrReference, document_schema_module.defs['example-or-reference'])
        namespace.const_set(:Link,         document_schema_module.defs['link'])
        namespace.const_set(:LinkOrReference, document_schema_module.defs['link-or-reference'])
        namespace.const_set(:Header,        document_schema_module.defs['header'])
        namespace.const_set(:HeaderOrReference, document_schema_module.defs['header-or-reference'])
        namespace.const_set(:Tag,            document_schema_module.defs['tag'])
        namespace.const_set(:Reference,       document_schema_module.defs['reference'])
        namespace.const_set(:Schema,           document_schema_module.defs['schema'])
        namespace.const_set(:SecurityScheme,    document_schema_module.defs['security-scheme'])
        namespace.const_set(:SecuritySchemeOrReference, document_schema_module.defs['security-scheme-or-reference'])
        namespace.const_set(:OAuthFlows,         document_schema_module.defs['oauth-flows'])
        namespace.const_set(:SecurityRequirement, document_schema_module.defs['security-requirement'])
        namespace.const_set(:SpecificationExtensions, document_schema_module.defs['specification-extensions'])
        namespace.const_set(:Examples,            document_schema_module.defs['examples'])
        namespace.const_set(:MapOfStrings,         document_schema_module.defs['map-of-strings'])
        namespace.const_set(:StylesForForm,         document_schema_module.defs['styles-for-form'])
        namespace.const_set(:SpecificationExtension, document_schema_module.defs['specification-extensions'].patternProperties["^x-"])
      end

      def self.set_up_document_schema_module(document_schema_module)
        document_schema_module.include(OpenAPI::V3_1::Document)
        document_schema_module.defs['operation'].include(OpenAPI::Operation::V3Methods)
        document_schema_module.defs['reference'].include(OpenAPI::Reference)
        document_schema_module.defs['tag'].include(OpenAPI::Tag)
        document_schema_module.defs['server'].include(OpenAPI::Server)
        document_schema_module.defs['paths'].include(OpenAPI::Paths)
        document_schema_module.defs['path-item'].include(OpenAPI::PathItem)

        document_schema_module
      end


      module Document
        include(OpenAPI::Document::V3Methods)
      end


      # namespace
      module Unscoped
      end

      Unscoped::Document = JSI.new_schema_module(
        YAML.safe_load(Scorpio.root.join('documents/spec.openapis.org/oas/3.1/schema.yaml').read),
      )
      # Schema module: describes an OpenAPI document, but not normally instantiated.
      #
      # This document schema has no dynamic scope pointing `$dynamicAnchor: "meta"` to a real
      # meta-schema. Schemas in the document described by this are just `type: [object, boolean]`,
      # have no dialect, and are not usable schemas.
      #
      # - $id: `https://spec.openapis.org/oas/3.1/schema/2022-10-07`
      module Unscoped::Document
      end
    end
  end
end
