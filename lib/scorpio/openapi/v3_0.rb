# frozen_string_literal: true

module Scorpio
  module OpenAPI
    module V3_0
      describe_schema_ptrs = Set[
        # this schema (Scorpio::OpenAPI::V3_0::Schema) describes schemas in an OpenAPI document.
        JSI::Ptr['definitions', 'Schema'],
        # /definitions/Schema does not allow $ref; this schema describes a schema with a $ref.
        JSI::Ptr['definitions', 'SchemaReference'],
        # this schema describes a boolean schema, only allowed for 'additionalProperties'
        JSI::Ptr['definitions', 'Schema', 'properties', 'additionalProperties', 'oneOf', 2],
      ].freeze

      Document = JSI::JSONSchemaDraft04.new_schema_module(YAML.safe_load(Scorpio.root.join(
        'documents/spec.openapis.org/oas/3.0/schema.yaml'
      ).read))

      describe_schema_ptrs.each do |ptr|
        (Document / ptr).describes_schema!(JSI::Schema::Draft04::DIALECT)
      end

      # naming these is not strictly necessary, but is nice to have.
      # generated: `puts Scorpio::OpenAPI::V3_0::Document.schema.definitions.keys.map { |k| "#{k[0].upcase}#{k[1..-1]} = Document.definitions['#{k}']" }`


      Reference      = Document.definitions['Reference']
      SchemaReference = Document.definitions['SchemaReference']
      Info           = Document.definitions['Info']
      Contact       = Document.definitions['Contact']
      License      = Document.definitions['License']
      Server        = Document.definitions['Server']
      ServerVariable = Document.definitions['ServerVariable']
      Components    = Document.definitions['Components']
      Schema       = Document.definitions['Schema']
      Discriminator = Document.definitions['Discriminator']
      XML          = Document.definitions['XML']
      Response    = Document.definitions['Response']
      MediaType    = Document.definitions['MediaType']
      Example       = Document.definitions['Example']
      Header         = Document.definitions['Header']
      Paths           = Document.definitions['Paths']
      PathItem         = Document.definitions['PathItem']
      Operation         = Document.definitions['Operation']
      Responses          = Document.definitions['Responses']
      SecurityRequirement = Document.definitions['SecurityRequirement']
      Tag                  = Document.definitions['Tag']
      ExternalDocumentation = Document.definitions['ExternalDocumentation']
      ExampleXORExamples   = Document.definitions['ExampleXORExamples']
      SchemaXORContent    = Document.definitions['SchemaXORContent']
      Parameter          = Document.definitions['Parameter']
      PathParameter      = Document.definitions['PathParameter']
      QueryParameter      = Document.definitions['QueryParameter']
      HeaderParameter      = Document.definitions['HeaderParameter']
      CookieParameter       = Document.definitions['CookieParameter']
      RequestBody            = Document.definitions['RequestBody']
      SecurityScheme          = Document.definitions['SecurityScheme']
      APIKeySecurityScheme     = Document.definitions['APIKeySecurityScheme']
      HTTPSecurityScheme        = Document.definitions['HTTPSecurityScheme']
      OAuth2SecurityScheme       = Document.definitions['OAuth2SecurityScheme']
      OpenIdConnectSecurityScheme = Document.definitions['OpenIdConnectSecurityScheme']
      OAuthFlows                 = Document.definitions['OAuthFlows']
      ImplicitOAuthFlow         = Document.definitions['ImplicitOAuthFlow']
      PasswordOAuthFlow        = Document.definitions['PasswordOAuthFlow']
      ClientCredentialsFlow     = Document.definitions['ClientCredentialsFlow']
      AuthorizationCodeOAuthFlow = Document.definitions['AuthorizationCodeOAuthFlow']
      Link                      = Document.definitions['Link']
      Callback                 = Document.definitions['Callback']
      Encoding                = Document.definitions['Encoding']

      # Describes a single API operation on a path.
      #
      # https://github.com/OAI/OpenAPI-Specification/blob/master/versions/3.0.2.md#operationObject
      module Operation
        include(OpenAPI::Operation::V3Methods)
      end

      # A document that defines or describes an API conforming to the OpenAPI Specification v3.0.
      #
      # https://github.com/OAI/OpenAPI-Specification/blob/master/versions/3.0.2.md#oasObject
      module Document
        include(OpenAPI::Document::V3Methods)

        # @return [#to_hash] /components/schemas, if present, or an empty hash
        def components_schemas
          return JSI::Util::EMPTY_HASH unless key?('components') && components.respond_to?(:to_hash)
          return JSI::Util::EMPTY_HASH unless components.key?('schemas') && components.schemas.respond_to?(:to_hash)
          components.schemas
        end
      end

      module Reference
        include(OpenAPI::Reference)
      end

      module Tag
        include(OpenAPI::Tag)
      end

      Document.properties["tags"].include(OpenAPI::Tags)

      # An object representing a Server.
      #
      # https://github.com/OAI/OpenAPI-Specification/blob/master/versions/3.0.2.md#serverObject
      module Server
        include(OpenAPI::Server)
      end

      module Paths
        include(OpenAPI::Paths)
      end

      module PathItem
        include(OpenAPI::PathItem)
        include(OpenAPI::Reference)
      end

      module SecurityScheme
        include(OpenAPI::SecurityScheme)
      end

      raise(Bug) unless Schema < JSI::Schema
      raise(Bug) unless SchemaReference < JSI::Schema
    end

    # @deprecated after v0.7
    V3 = V3_0
  end
end
