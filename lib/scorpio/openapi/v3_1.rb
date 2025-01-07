# frozen_string_literal: true

module Scorpio
  module OpenAPI
    module V3_1
      class << self
        attr_accessor(:document_schema_modules_by_dialect_id)
      end

      self.document_schema_modules_by_dialect_id = {}

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
        namespace.const_set(:RequestBody,         document_schema_module.defs['request-body'])
        namespace.const_set(:Content,            document_schema_module.defs['content'])
        namespace.const_set(:MediaType,         document_schema_module.defs['media-type'])
        namespace.const_set(:Encoding,         document_schema_module.defs['encoding'])
        namespace.const_set(:Responses,       document_schema_module.defs['responses'])
        namespace.const_set(:Response,       document_schema_module.defs['response'])
        namespace.const_set(:Callbacks,     document_schema_module.defs['callbacks'])
        namespace.const_set(:Example,      document_schema_module.defs['example'])
        namespace.const_set(:Link,         document_schema_module.defs['link'])
        namespace.const_set(:Header,        document_schema_module.defs['header'])
        namespace.const_set(:Tag,            document_schema_module.defs['tag'])
        namespace.const_set(:Reference,       document_schema_module.defs['reference'])
        namespace.const_set(:Schema,           document_schema_module.defs['schema'])
        namespace.const_set(:SecurityScheme,    document_schema_module.defs['security-scheme'])
        namespace.const_set(:OAuthFlows,         document_schema_module.defs['oauth-flows'])
        namespace.const_set(:SecurityRequirement, document_schema_module.defs['security-requirement'])
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
        document_schema_module.defs['path-item'].include(OpenAPI::Reference)
        document_schema_module.defs['security-scheme'].include(OpenAPI::SecurityScheme)

        document_schema_module
      end

      # This is pretty much: `Unscoped::Document.with_dynamic_scope_from(JSI.registry.find(dialect_id))`
      # plus {.set_up_document_schema_module}.
      #
      # However, this also supports a dialect whose meta-schema isn't aware of dynamic scope and doesn't
      # have a `$dynamicAnchor: "meta"`, e.g. `jsonSchemaDialect: "http://json-schema.org/draft-07/schema"`.
      #
      # A schema like {Ext::ExtDocument} exists to `$ref` to {Unscoped::Document} with anchor `meta`
      # in dynamic scope, with the `$dynamicAnchor: "meta"` schema `$ref`ing to {Ext::MetaSchema}.
      # This method obviates the need for such a schema, directly applying dynamic scope.
      def self.document_schema_module_by_dialect_id(dialect_id)
        dialect_uri = JSI::Util.uri(dialect_id)
        document_schema_modules_by_dialect_id[dialect_uri] ||= begin
          metaschema = JSI.registry.find(dialect_uri)
          dynamic_anchor_map = metaschema.jsi_next_schema_dynamic_anchor_map
          unless dynamic_anchor_map.key?('meta')
            # hax: pretend that the identified meta-schema has `$dynamicAnchor: "meta"`
            # this enables e.g. `jsonSchemaDialect: "http://json-schema.org/draft-07/schema"` to work
            # this is non-API JSI internals.
            dynamic_anchor_map = dynamic_anchor_map.merge({
              'meta' => [metaschema, [].freeze].freeze,
            }).freeze
          end
          document_schema = Unscoped::Document.schema.jsi_with_schema_dynamic_anchor_map(dynamic_anchor_map)
          set_up_document_schema_module(document_schema.jsi_schema_module)
        end
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

      set_up_document_schema_module(Unscoped::Document)
      document_name_subschemas(Unscoped::Document, Unscoped)
      # if jsonSchemaDialect is explicit nil, instantiate a document with no meta-schema in dynamic scope.
      # note the default when jsonSchemaDialect is absent is not nil, it is Unscoped::Document.properties['jsonSchemaDialect'].default.
      document_schema_modules_by_dialect_id[nil] = Unscoped::Document


      # "Ext" is abbreviation for the "OpenAPI extension schema dialect" that extends JSON Schema draft 2020-12
      # and defines keywords: `discriminator`, `example`, `externalDocs`, `xml`.
      # This module is a namespace for that.
      module Ext
      end

      # vocabulary for implementation of keywords: `discriminator`, `example`, `externalDocs`, `xml`
      Ext::VOCAB = JSI::Schema::Vocabulary.new(
        id: "https://spec.openapis.org/oas/3.1/vocab/base",
        elements: [
          # TODO:
          # - discriminator
          # - example
          # - externalDocs
          # - xml
        ],
      )
      JSI.registry.register_vocabulary(Ext::VOCAB)


      Ext::ExtDocument = JSI.new_schema_module(
        YAML.safe_load(Scorpio.root.join('documents/spec.openapis.org/oas/3.1/schema-base.yaml').read),
      )
      # Schema module: Describes an OAD with schemas of the OpenAPI extension schema dialect.
      # This exists to dynamically scope the `meta` anchor
      # for {Unscoped::Document} `<https://spec.openapis.org/oas/3.1/schema/2022-10-07>`
      # to {Ext::MetaSchema} `<https://spec.openapis.org/oas/3.1/dialect/base>`
      # via `<#/$defs/schema>` {Ext::ExtDocument::Schema}.
      #
      # - $id: `https://spec.openapis.org/oas/3.1/schema-base/2022-10-07`
      # - $ref: {Ext::Document} `<https://spec.openapis.org/oas/3.1/schema/2022-10-07>`
      # - $dynamicAnchor: `meta` in `/$defs/schema` ({Ext::ExtDocument::Schema})
      # - properties: jsonSchemaDialect const {Ext::MetaSchema} `<https://spec.openapis.org/oas/3.1/dialect/base>`
      module Ext::ExtDocument
      end

      Ext::ExtDocument::Schema = Ext::ExtDocument["$defs"]["schema"]
      # Schema module: Describes schemas in an Ext::Document
      #
      # - $dynamicAnchor: `meta`
      # - $ref: {Ext::MetaSchema} `<https://spec.openapis.org/oas/3.1/dialect/base>`
      # - properties: $schema const {Ext::MetaSchema} `<https://spec.openapis.org/oas/3.1/dialect/base>`
      module Ext::ExtDocument::Schema
      end


      # Some Ext schemas are used with dynamic scope from {Ext::ExtDocument}; Ext::Unscoped namespace
      # contains those schemas without that dynamic scope. These are not normally instantiated.
      module Ext::Unscoped
      end

      Ext::Unscoped::VocabSchema = JSI.new_schema_module(
        YAML.safe_load(Scorpio.root.join('documents/spec.openapis.org/oas/3.1/meta/base.schema.yaml').read),
      )
      module Ext::Unscoped::VocabSchema
      end

      Ext::VocabSchema = Ext::Unscoped::VocabSchema.with_dynamic_scope_from(Ext::ExtDocument)
      # Schema module: vocabulary schema for {Ext::VOCAB}
      #
      # - $id: `https://spec.openapis.org/oas/3.1/meta/base`
      # - $dynamicAnchor: `meta` (unused)
      # - properties (schema keywords) discriminator, example, externalDocs, xml
      module Ext::VocabSchema
      end

      Ext::Unscoped::MetaSchema = JSI.new_schema_module(
        YAML.safe_load(Scorpio.root.join('documents/spec.openapis.org/oas/3.1/dialect/base.schema.yaml').read),
      )
      module Ext::Unscoped::MetaSchema
      end

      Ext::MetaSchema = Ext::Unscoped::MetaSchema.with_dynamic_scope_from(Ext::ExtDocument)
      Ext::MetaSchema.describes_schema!
      # Schema module: Meta-schema describing schemas within an OpenAPI document with the OpenAPI extension schema dialect
      #
      # - $id: `https://spec.openapis.org/oas/3.1/dialect/base`
      # - $dynamicAnchor: `meta` (overridden by dynamic scope with `meta` → {Ext::ExtDocument::Schema})
      # - $vocabulary:
      #   - The draft/2020-12 vocabularies - core, applicator, validation, etc (required: true)
      #   - {Ext::VOCAB} `<https://spec.openapis.org/oas/3.1/vocab/base>` (required: false)
      # - allOf:
      #   - $ref: JSI::JSONSchemaDraft202012 `<https://json-schema.org/draft/2020-12/schema>` (with dynamic scope meta → {Ext::ExtDocument::Schema})
      #   - $ref: {Ext::VocabSchema} `<https://spec.openapis.org/oas/3.1/meta/base>`
      module Ext::MetaSchema
      end

      Ext::Document = Unscoped::Document.with_dynamic_scope_from(Ext::ExtDocument)
      # Schema module: Describes an OpenAPI document containing schemas of the Ext dialect.
      # This is {Unscoped::Document}, with dynamic scope pointing `$dynamicAnchor: "meta"` to {Ext::ExtDocument::Schema}.
      module Ext::Document
      end
    end
  end
end
