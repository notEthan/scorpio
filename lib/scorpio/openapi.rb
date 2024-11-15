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
    autoload :OperationsScope, 'scorpio/openapi/operations_scope'

    module V3
      openapi_document_schema = JSI::JSONSchemaDraft04.new_schema(::YAML.load_file(Scorpio.root.join(
        'documents/spec.openapis.org/oas/3.0/schema.yaml'
      )))

      # the schema represented by Scorpio::OpenAPI::V3::Schema will describe schemas itself.
      # JSI::Schema#describes_schema! enables this to implement the functionality of schemas.
      describe_schema = [
        openapi_document_schema.definitions['Schema'],
        openapi_document_schema.definitions['SchemaReference'],
        # instead of the Schema definition allowing boolean, properties['additionalProperties']
        # is a oneOf which allows a Schema, SchemaReference, or boolean.
        # instances of the former two already include the schema implementation (per the previous
        # describes_schema entries), but the boolean does not.
        # including in properties['additionalProperties'] applies to any additionalProperties.
        # (including in properties['additionalProperties'].anyOf[2] would extend booleans too, without
        # the redundant inclusion that results for Schema and SchemaRef, but redundant inclusion is not
        # a problem, and this way also applies when none of the anyOf match due to schema errors.)
        openapi_document_schema.definitions['Schema'].properties['additionalProperties'],
      ]
      describe_schema.each { |s| s.describes_schema!([JSI::Schema::Draft04]) }

      Document = openapi_document_schema.jsi_schema_module

      # naming these is not strictly necessary, but is nice to have.
      # generated: `puts Scorpio::OpenAPI::V3::Document.schema.definitions.keys.map { |k| "#{k[0].upcase}#{k[1..-1]} = Document.definitions['#{k}']" }`


      Reference      = Document.definitions['Reference']
      SchemaReference = Document.definitions['SchemaReference']
      Info           = Document.definitions['Info']
      Contact       = Document.definitions['Contact']
      License       = Document.definitions['License']
      Server         = Document.definitions['Server']
      ServerVariable  = Document.definitions['ServerVariable']
      Components       = Document.definitions['Components']
      Schema            = Document.definitions['Schema']
      Discriminator      = Document.definitions['Discriminator']
      XML                 = Document.definitions['XML']
      Response             = Document.definitions['Response']
      MediaType             = Document.definitions['MediaType']
      MediaTypeWithExample   = Document.definitions['MediaTypeWithExample']
      MediaTypeWithExamples   = Document.definitions['MediaTypeWithExamples']
      Example                  = Document.definitions['Example']
      Header                    = Document.definitions['Header']
      HeaderWithSchema           = Document.definitions['HeaderWithSchema']
      HeaderWithSchemaWithExample = Document.definitions['HeaderWithSchemaWithExample']
      HeaderWithSchemaWithExamples = Document.definitions['HeaderWithSchemaWithExamples']
      HeaderWithContent           = Document.definitions['HeaderWithContent']
      Paths                      = Document.definitions['Paths']
      PathItem                    = Document.definitions['PathItem']
      Operation                    = Document.definitions['Operation']
      Responses                     = Document.definitions['Responses']
      SecurityRequirement            = Document.definitions['SecurityRequirement']
      Tag                             = Document.definitions['Tag']
      ExternalDocumentation            = Document.definitions['ExternalDocumentation']
      Parameter                         = Document.definitions['Parameter']
      ParameterWithSchema                = Document.definitions['ParameterWithSchema']
      ParameterWithSchemaWithExample      = Document.definitions['ParameterWithSchemaWithExample']
      ParameterWithSchemaWithExampleInPath = Document.definitions['ParameterWithSchemaWithExampleInPath']
      ParameterWithSchemaWithExampleInQuery = Document.definitions['ParameterWithSchemaWithExampleInQuery']
      ParameterWithSchemaWithExampleInHeader = Document.definitions['ParameterWithSchemaWithExampleInHeader']
      ParameterWithSchemaWithExampleInCookie = Document.definitions['ParameterWithSchemaWithExampleInCookie']
      ParameterWithSchemaWithExamples       = Document.definitions['ParameterWithSchemaWithExamples']
      ParameterWithSchemaWithExamplesInPath = Document.definitions['ParameterWithSchemaWithExamplesInPath']
      ParameterWithSchemaWithExamplesInQuery = Document.definitions['ParameterWithSchemaWithExamplesInQuery']
      ParameterWithSchemaWithExamplesInHeader = Document.definitions['ParameterWithSchemaWithExamplesInHeader']
      ParameterWithSchemaWithExamplesInCookie = Document.definitions['ParameterWithSchemaWithExamplesInCookie']
      ParameterWithContent                   = Document.definitions['ParameterWithContent']
      ParameterWithContentInPath            = Document.definitions['ParameterWithContentInPath']
      ParameterWithContentNotInPath        = Document.definitions['ParameterWithContentNotInPath']
      RequestBody                         = Document.definitions['RequestBody']
      SecurityScheme                     = Document.definitions['SecurityScheme']
      APIKeySecurityScheme              = Document.definitions['APIKeySecurityScheme']
      HTTPSecurityScheme               = Document.definitions['HTTPSecurityScheme']
      NonBearerHTTPSecurityScheme     = Document.definitions['NonBearerHTTPSecurityScheme']
      BearerHTTPSecurityScheme       = Document.definitions['BearerHTTPSecurityScheme']
      OAuth2SecurityScheme          = Document.definitions['OAuth2SecurityScheme']
      OpenIdConnectSecurityScheme  = Document.definitions['OpenIdConnectSecurityScheme']
      OAuthFlows                  = Document.definitions['OAuthFlows']
      ImplicitOAuthFlow          = Document.definitions['ImplicitOAuthFlow']
      PasswordOAuthFlow         = Document.definitions['PasswordOAuthFlow']
      ClientCredentialsFlow     = Document.definitions['ClientCredentialsFlow']
      AuthorizationCodeOAuthFlow = Document.definitions['AuthorizationCodeOAuthFlow']
      Link                      = Document.definitions['Link']
      LinkWithOperationRef     = Document.definitions['LinkWithOperationRef']
      LinkWithOperationId     = Document.definitions['LinkWithOperationId']
      Callback               = Document.definitions['Callback']
      Encoding              = Document.definitions['Encoding']

      raise(Bug) unless Schema < JSI::Schema
      raise(Bug) unless SchemaReference < JSI::Schema
    end
    module V2
      openapi_document_schema = JSI.new_schema(::JSON.parse(Scorpio.root.join(
        'documents/swagger.io/v2/schema.json'
      ).read))

      # the schema represented by Scorpio::OpenAPI::V2::Schema will describe schemas itself.
      # JSI::Schema#describes_schema! enables this to implement the functionality of schemas.
      describe_schema = [
        openapi_document_schema.definitions['schema'],
        # comments above on v3's definitions['Schema'].properties['additionalProperties'] apply here too
        openapi_document_schema.definitions['schema'].properties['additionalProperties'],
      ]
      describe_schema.each { |s| s.describes_schema!([JSI::Schema::Draft04]) }

      Document = openapi_document_schema.jsi_schema_module

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

      raise(Bug) unless Schema < JSI::Schema
    end

    # the autoloads for OpenAPI::Operation and OpenAPI::Document are triggered below. these
    # should not be triggered until all the classes their files reference are defined (above).


    module V3
      module Operation
        include OpenAPI::Operation
      end
      module Document
        include OpenAPI::Document
      end
      module Reference
        include OpenAPI::Reference
      end
      module Tag
        include OpenAPI::Tag
      end
      require 'scorpio/openapi/v3/server'
    end

    module V2
      module Operation
        include OpenAPI::Operation
      end
      module Document
        include OpenAPI::Document
      end
      module JsonReference
        include OpenAPI::Reference
      end
      module Tag
        include OpenAPI::Tag
      end
    end
  end
end
