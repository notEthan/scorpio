module Scorpio
  module OpenAPI
    autoload :Operation, 'scorpio/openapi/operation'
    autoload :Document, 'scorpio/openapi/document'
    autoload :OperationsScope, 'scorpio/openapi/operations_scope'

    module V3
      openapi_schema = JSI::Schema.new(::YAML.load_file(Scorpio.root.join('documents/github.com/OAI/OpenAPI-Specification/blob/oas3-schema/schemas/v3.0/schema.yaml')))
      openapi_class = proc do |*key|
        JSI.class_for_schema(key.inject(openapi_schema, &:[]))
      end

      Document = openapi_class.call()

      # naming these is not strictly necessary, but is nice to have.
      # generated: puts JSI::Schema.new(::YAML.load_file(Scorpio.root.join('documents/github.com/OAI/OpenAPI-Specification/blob/oas3-schema/schemas/v3.0/schema.yaml')))['definitions'].select { |k,v| ['object', nil].include?(v['type']) }.keys.map { |k| "#{k[0].upcase}#{k[1..-1]} = openapi_class.call('definitions', '#{k}')" }
      Reference  = openapi_class.call('definitions', 'Reference')
      Info        = openapi_class.call('definitions', 'Info')
      Contact      = openapi_class.call('definitions', 'Contact')
      License       = openapi_class.call('definitions', 'License')
      Server         = openapi_class.call('definitions', 'Server')
      ServerVariable  = openapi_class.call('definitions', 'ServerVariable')
      Components       = openapi_class.call('definitions', 'Components')
      Schema            = openapi_class.call('definitions', 'Schema')
      Discriminator      = openapi_class.call('definitions', 'Discriminator')
      XML                 = openapi_class.call('definitions', 'XML')
      Response             = openapi_class.call('definitions', 'Response')
      MediaType             = openapi_class.call('definitions', 'MediaType')
      MediaTypeWithExample   = openapi_class.call('definitions', 'MediaTypeWithExample')
      MediaTypeWithExamples   = openapi_class.call('definitions', 'MediaTypeWithExamples')
      Example                  = openapi_class.call('definitions', 'Example')
      Header                    = openapi_class.call('definitions', 'Header')
      HeaderWithSchema           = openapi_class.call('definitions', 'HeaderWithSchema')
      HeaderWithSchemaWithExample = openapi_class.call('definitions', 'HeaderWithSchemaWithExample')
      HeaderWithSchemaWithExamples = openapi_class.call('definitions', 'HeaderWithSchemaWithExamples')
      HeaderWithContent           = openapi_class.call('definitions', 'HeaderWithContent')
      Paths                      = openapi_class.call('definitions', 'Paths')
      PathItem                    = openapi_class.call('definitions', 'PathItem')
      Operation                    = openapi_class.call('definitions', 'Operation')
      Responses                     = openapi_class.call('definitions', 'Responses')
      SecurityRequirement            = openapi_class.call('definitions', 'SecurityRequirement')
      Tag                             = openapi_class.call('definitions', 'Tag')
      ExternalDocumentation            = openapi_class.call('definitions', 'ExternalDocumentation')
      Parameter                         = openapi_class.call('definitions', 'Parameter')
      ParameterWithSchema                = openapi_class.call('definitions', 'ParameterWithSchema')
      ParameterWithSchemaWithExample      = openapi_class.call('definitions', 'ParameterWithSchemaWithExample')
      ParameterWithSchemaWithExampleInPath = openapi_class.call('definitions', 'ParameterWithSchemaWithExampleInPath')
      ParameterWithSchemaWithExampleInQuery = openapi_class.call('definitions', 'ParameterWithSchemaWithExampleInQuery')
      ParameterWithSchemaWithExampleInHeader = openapi_class.call('definitions', 'ParameterWithSchemaWithExampleInHeader')
      ParameterWithSchemaWithExampleInCookie = openapi_class.call('definitions', 'ParameterWithSchemaWithExampleInCookie')
      ParameterWithSchemaWithExamples       = openapi_class.call('definitions', 'ParameterWithSchemaWithExamples')
      ParameterWithSchemaWithExamplesInPath = openapi_class.call('definitions', 'ParameterWithSchemaWithExamplesInPath')
      ParameterWithSchemaWithExamplesInQuery = openapi_class.call('definitions', 'ParameterWithSchemaWithExamplesInQuery')
      ParameterWithSchemaWithExamplesInHeader = openapi_class.call('definitions', 'ParameterWithSchemaWithExamplesInHeader')
      ParameterWithSchemaWithExamplesInCookie = openapi_class.call('definitions', 'ParameterWithSchemaWithExamplesInCookie')
      ParameterWithContent                   = openapi_class.call('definitions', 'ParameterWithContent')
      ParameterWithContentInPath            = openapi_class.call('definitions', 'ParameterWithContentInPath')
      ParameterWithContentNotInPath        = openapi_class.call('definitions', 'ParameterWithContentNotInPath')
      RequestBody                         = openapi_class.call('definitions', 'RequestBody')
      SecurityScheme                     = openapi_class.call('definitions', 'SecurityScheme')
      APIKeySecurityScheme              = openapi_class.call('definitions', 'APIKeySecurityScheme')
      HTTPSecurityScheme               = openapi_class.call('definitions', 'HTTPSecurityScheme')
      NonBearerHTTPSecurityScheme     = openapi_class.call('definitions', 'NonBearerHTTPSecurityScheme')
      BearerHTTPSecurityScheme       = openapi_class.call('definitions', 'BearerHTTPSecurityScheme')
      OAuth2SecurityScheme          = openapi_class.call('definitions', 'OAuth2SecurityScheme')
      OpenIdConnectSecurityScheme  = openapi_class.call('definitions', 'OpenIdConnectSecurityScheme')
      OAuthFlows                  = openapi_class.call('definitions', 'OAuthFlows')
      ImplicitOAuthFlow          = openapi_class.call('definitions', 'ImplicitOAuthFlow')
      PasswordOAuthFlow         = openapi_class.call('definitions', 'PasswordOAuthFlow')
      ClientCredentialsFlow     = openapi_class.call('definitions', 'ClientCredentialsFlow')
      AuthorizationCodeOAuthFlow = openapi_class.call('definitions', 'AuthorizationCodeOAuthFlow')
      Link                      = openapi_class.call('definitions', 'Link')
      LinkWithOperationRef     = openapi_class.call('definitions', 'LinkWithOperationRef')
      LinkWithOperationId     = openapi_class.call('definitions', 'LinkWithOperationId')
      Callback               = openapi_class.call('definitions', 'Callback')
      Encoding              = openapi_class.call('definitions', 'Encoding')
    end
    module V2
      openapi_schema = JSI::Schema.new(::JSON.parse(Scorpio.root.join('documents/swagger.io/v2/schema.json').read))
      openapi_class = proc do |*key|
        JSI.class_for_schema(key.inject(openapi_schema, &:[]))
      end

      Document = openapi_class.call()

      # naming these is not strictly necessary, but is nice to have.
      # generated: puts Scorpio::OpenAPI::V2::Document.schema['definitions'].select { |k,v| ['object', nil].include?(v['type']) }.keys.map { |k| "#{k[0].upcase}#{k[1..-1]} = openapi_class.call('definitions', '#{k}')" }
      Info            = openapi_class.call('definitions', 'info')
      Contact          = openapi_class.call('definitions', 'contact')
      License           = openapi_class.call('definitions', 'license')
      Paths              = openapi_class.call('definitions', 'paths')
      Definitions         = openapi_class.call('definitions', 'definitions')
      ParameterDefinitions = openapi_class.call('definitions', 'parameterDefinitions')
      ResponseDefinitions = openapi_class.call('definitions', 'responseDefinitions')
      ExternalDocs       = openapi_class.call('definitions', 'externalDocs')
      Examples          = openapi_class.call('definitions', 'examples')
      Operation        = openapi_class.call('definitions', 'operation')
      PathItem         = openapi_class.call('definitions', 'pathItem')
      Responses         = openapi_class.call('definitions', 'responses')
      ResponseValue      = openapi_class.call('definitions', 'responseValue')
      Response            = openapi_class.call('definitions', 'response')
      Headers              = openapi_class.call('definitions', 'headers')
      Header                = openapi_class.call('definitions', 'header')
      VendorExtension        = openapi_class.call('definitions', 'vendorExtension')
      BodyParameter           = openapi_class.call('definitions', 'bodyParameter')
      HeaderParameterSubSchema = openapi_class.call('definitions', 'headerParameterSubSchema')
      QueryParameterSubSchema   = openapi_class.call('definitions', 'queryParameterSubSchema')
      FormDataParameterSubSchema = openapi_class.call('definitions', 'formDataParameterSubSchema')
      PathParameterSubSchema    = openapi_class.call('definitions', 'pathParameterSubSchema')
      NonBodyParameter         = openapi_class.call('definitions', 'nonBodyParameter')
      Parameter               = openapi_class.call('definitions', 'parameter')
      Schema                 = openapi_class.call('definitions', 'schema')
      FileSchema            = openapi_class.call('definitions', 'fileSchema')
      PrimitivesItems        = openapi_class.call('definitions', 'primitivesItems')
      SecurityRequirement     = openapi_class.call('definitions', 'securityRequirement')
      Xml                      = openapi_class.call('definitions', 'xml')
      Tag                       = openapi_class.call('definitions', 'tag')
      SecurityDefinitions        = openapi_class.call('definitions', 'securityDefinitions')
      BasicAuthenticationSecurity = openapi_class.call('definitions', 'basicAuthenticationSecurity')
      ApiKeySecurity             = openapi_class.call('definitions', 'apiKeySecurity')
      Oauth2ImplicitSecurity    = openapi_class.call('definitions', 'oauth2ImplicitSecurity')
      Oauth2PasswordSecurity   = openapi_class.call('definitions', 'oauth2PasswordSecurity')
      Oauth2ApplicationSecurity = openapi_class.call('definitions', 'oauth2ApplicationSecurity')
      Oauth2AccessCodeSecurity = openapi_class.call('definitions', 'oauth2AccessCodeSecurity')
      Oauth2Scopes            = openapi_class.call('definitions', 'oauth2Scopes')
      Title                  = openapi_class.call('definitions', 'title')
      Description           = openapi_class.call('definitions', 'description')
      Default              = openapi_class.call('definitions', 'default')
      MultipleOf          = openapi_class.call('definitions', 'multipleOf')
      Maximum            = openapi_class.call('definitions', 'maximum')
      ExclusiveMaximum  = openapi_class.call('definitions', 'exclusiveMaximum')
      Minimum          = openapi_class.call('definitions', 'minimum')
      ExclusiveMinimum = openapi_class.call('definitions', 'exclusiveMinimum')
      MaxLength       = openapi_class.call('definitions', 'maxLength')
      MinLength      = openapi_class.call('definitions', 'minLength')
      Pattern       = openapi_class.call('definitions', 'pattern')
      MaxItems     = openapi_class.call('definitions', 'maxItems')
      MinItems    = openapi_class.call('definitions', 'minItems')
      UniqueItems = openapi_class.call('definitions', 'uniqueItems')
      Enum         = openapi_class.call('definitions', 'enum')
      JsonReference = openapi_class.call('definitions', 'jsonReference')
    end

    begin
      # the autoloads for OpenAPI::Operation and OpenAPI::Document
      # should not be triggered until all the classes their files reference are defined (above)
    end # (this block is here just so the above informative comment is not interpreted as module doc)

    module V3
      class Operation
        include OpenAPI::Operation
      end
      class Document
        include OpenAPI::Document
      end
      require 'scorpio/openapi/v3/server'
    end

    module V2
      class Operation
        include OpenAPI::Operation
      end
      class Document
        include OpenAPI::Document
      end
    end
  end
end
