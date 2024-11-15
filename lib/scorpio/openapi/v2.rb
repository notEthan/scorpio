# frozen_string_literal: true

module Scorpio
  module OpenAPI
    module V2
      Document = JSI.new_schema_module(JSON.parse(Scorpio.root.join(
        'documents/swagger.io/v2/schema.json'
      ).read))

      # the schema represented by Scorpio::OpenAPI::V2::Schema will describe schemas itself.
      # JSI::Schema#describes_schema! enables this to implement the functionality of schemas.
      describe_schema = [
        Document.schema.definitions['schema'],
        # comments on V3_0's Document.definitions['Schema'].properties['additionalProperties'] apply here too
        Document.schema.definitions['schema'].properties['additionalProperties'],
      ]
      describe_schema.each { |s| s.describes_schema!(JSI::Schema::Draft04::DIALECT) }

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
      Oauth2ImplicitSecurity    = Document.definitions['oauth2ImplicitSecurity']
      Oauth2PasswordSecurity   = Document.definitions['oauth2PasswordSecurity']
      Oauth2ApplicationSecurity = Document.definitions['oauth2ApplicationSecurity']
      Oauth2AccessCodeSecurity = Document.definitions['oauth2AccessCodeSecurity']
      Oauth2Scopes            = Document.definitions['oauth2Scopes']
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

      raise(Bug) unless Schema < JSI::Schema
    end
  end
end
