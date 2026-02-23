# frozen_string_literal: true

module Scorpio
  module OpenAPI
    module V2
      describe_schema_ptrs = Set[
        # this schema (Scorpio::OpenAPI::V2::Schema) describes schemas in an OpenAPI document.
        JSI::Ptr['definitions', 'schema'],
        # this schema describes a boolean schema, only allowed for 'additionalProperties'
        JSI::Ptr['definitions', 'schema', 'properties', 'additionalProperties', 'anyOf', 1],
      ].freeze

      Document = JSI.new_schema_module(JSON.parse(Scorpio.root.join(
        'documents/swagger.io/v2/schema.json'
      ).read, freeze: true))

      describe_schema_ptrs.each do |ptr|
        (Document / ptr).describes_schema!(JSI::Schema::Draft04::DIALECT)
      end

      # naming these is not strictly necessary, but is nice to have.
      # generated: `puts Scorpio::OpenAPI::V2::Document.schema.definitions.keys.map { |k| "#{k[0].upcase}#{k[1..-1]} = Document.definitions['#{k}']" }`


      Info            = Document.definitions['info']
      Contact          = Document.definitions['contact']
      License           = Document.definitions['license']
      Paths              = Document.definitions['paths']
      Definitions         = Document.definitions['definitions']
      ParameterDefinitions = Document.definitions['parameterDefinitions']
      ResponseDefinitions = Document.definitions['responseDefinitions']
      ExternalDocs       = Document.definitions['externalDocs']
      Examples          = Document.definitions['examples']
      MimeType         = Document.definitions['mimeType']
      Operation       = Document.definitions['operation']
      PathItem         = Document.definitions['pathItem']
      Responses         = Document.definitions['responses']
      ResponseValue      = Document.definitions['responseValue']
      Response            = Document.definitions['response']
      Headers              = Document.definitions['headers']
      Header                = Document.definitions['header']
      VendorExtension        = Document.definitions['vendorExtension']
      BodyParameter           = Document.definitions['bodyParameter']
      HeaderParameterSubSchema = Document.definitions['headerParameterSubSchema']
      QueryParameterSubSchema   = Document.definitions['queryParameterSubSchema']
      FormDataParameterSubSchema = Document.definitions['formDataParameterSubSchema']
      PathParameterSubSchema    = Document.definitions['pathParameterSubSchema']
      NonBodyParameter         = Document.definitions['nonBodyParameter']
      Parameter               = Document.definitions['parameter']
      Schema                 = Document.definitions['schema']
      FileSchema            = Document.definitions['fileSchema']
      PrimitivesItems       = Document.definitions['primitivesItems']
      Security               = Document.definitions['security']
      SecurityRequirement     = Document.definitions['securityRequirement']
      Xml                      = Document.definitions['xml']
      Tag                       = Document.definitions['tag']
      SecurityDefinitions        = Document.definitions['securityDefinitions']
      BasicAuthenticationSecurity = Document.definitions['basicAuthenticationSecurity']
      ApiKeySecurity             = Document.definitions['apiKeySecurity']
      OAuth2ImplicitSecurity    = Document.definitions['oauth2ImplicitSecurity']
      OAuth2PasswordSecurity   = Document.definitions['oauth2PasswordSecurity']
      OAuth2ApplicationSecurity = Document.definitions['oauth2ApplicationSecurity']
      OAuth2AccessCodeSecurity = Document.definitions['oauth2AccessCodeSecurity']
      OAuth2Scopes            = Document.definitions['oauth2Scopes']
      MediaTypeList          = Document.definitions['mediaTypeList']
      ParametersList         = Document.definitions['parametersList']
      SchemesList             = Document.definitions['schemesList']
      CollectionFormat         = Document.definitions['collectionFormat']
      CollectionFormatWithMulti = Document.definitions['collectionFormatWithMulti']
      Title                    = Document.definitions['title']
      Description             = Document.definitions['description']
      Default                = Document.definitions['default']
      MultipleOf            = Document.definitions['multipleOf']
      Maximum              = Document.definitions['maximum']
      ExclusiveMaximum    = Document.definitions['exclusiveMaximum']
      Minimum            = Document.definitions['minimum']
      ExclusiveMinimum  = Document.definitions['exclusiveMinimum']
      MaxLength        = Document.definitions['maxLength']
      MinLength       = Document.definitions['minLength']
      Pattern        = Document.definitions['pattern']
      MaxItems      = Document.definitions['maxItems']
      MinItems     = Document.definitions['minItems']
      UniqueItems = Document.definitions['uniqueItems']
      Enum         = Document.definitions['enum']
      JsonReference = Document.definitions['jsonReference']

      module Operation
        include(OpenAPI::Operation::V2Methods)
      end

      # A document that defines or describes an API conforming to the OpenAPI Specification v2 (aka Swagger).
      #
      # The root document is known as the Swagger Object.
      module Document
        include(OpenAPI::Document::V2Methods)
      end

      module JsonReference
        include(OpenAPI::Reference)
      end

      module Tag
        include(OpenAPI::Tag)
      end

      Document.properties["tags"].include(OpenAPI::Tags)

      module Paths
        include(OpenAPI::Paths)
      end

      module PathItem
        include(OpenAPI::PathItem)
        include(OpenAPI::Reference)
      end
    end
  end
end
