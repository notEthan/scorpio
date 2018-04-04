require 'scorpio/schema_object_base'

module Scorpio
  module Swagger
    swagger_schema_doc = ::JSON.parse(Scorpio.root.join('documents/swagger.io/v2/schema.json').read)
    swagger_class = proc do |*key|
      Scorpio.class_for_schema(Scorpio::JSON::Node.new_by_type(swagger_schema_doc, key))
    end

    Document = swagger_class.call()

    # naming these is not strictly necessary, but is nice to have.
    # generated: puts Scorpio::Swagger::Document.schema_document['definitions'].select { |k,v| ['object', nil].include?(v['type']) }.keys.map { |k| "#{k[0].upcase}#{k[1..-1]} = swagger_class.call('definitions', '#{k}')" }
    Info                        = swagger_class.call('definitions', 'info')
    Contact                     = swagger_class.call('definitions', 'contact')
    License                     = swagger_class.call('definitions', 'license')
    Paths                       = swagger_class.call('definitions', 'paths')
    Definitions                 = swagger_class.call('definitions', 'definitions')
    ParameterDefinitions        = swagger_class.call('definitions', 'parameterDefinitions')
    ResponseDefinitions         = swagger_class.call('definitions', 'responseDefinitions')
    ExternalDocs                = swagger_class.call('definitions', 'externalDocs')
    Examples                    = swagger_class.call('definitions', 'examples')
    Operation                   = swagger_class.call('definitions', 'operation')
    PathItem                    = swagger_class.call('definitions', 'pathItem')
    Responses                   = swagger_class.call('definitions', 'responses')
    ResponseValue               = swagger_class.call('definitions', 'responseValue')
    Response                    = swagger_class.call('definitions', 'response')
    Headers                     = swagger_class.call('definitions', 'headers')
    Header                      = swagger_class.call('definitions', 'header')
    VendorExtension             = swagger_class.call('definitions', 'vendorExtension')
    BodyParameter               = swagger_class.call('definitions', 'bodyParameter')
    HeaderParameterSubSchema    = swagger_class.call('definitions', 'headerParameterSubSchema')
    QueryParameterSubSchema     = swagger_class.call('definitions', 'queryParameterSubSchema')
    FormDataParameterSubSchema  = swagger_class.call('definitions', 'formDataParameterSubSchema')
    PathParameterSubSchema      = swagger_class.call('definitions', 'pathParameterSubSchema')
    NonBodyParameter            = swagger_class.call('definitions', 'nonBodyParameter')
    Parameter                   = swagger_class.call('definitions', 'parameter')
    Schema                      = swagger_class.call('definitions', 'schema')
    FileSchema                  = swagger_class.call('definitions', 'fileSchema')
    PrimitivesItems             = swagger_class.call('definitions', 'primitivesItems')
    SecurityRequirement         = swagger_class.call('definitions', 'securityRequirement')
    Xml                         = swagger_class.call('definitions', 'xml')
    Tag                         = swagger_class.call('definitions', 'tag')
    SecurityDefinitions         = swagger_class.call('definitions', 'securityDefinitions')
    BasicAuthenticationSecurity = swagger_class.call('definitions', 'basicAuthenticationSecurity')
    ApiKeySecurity              = swagger_class.call('definitions', 'apiKeySecurity')
    Oauth2ImplicitSecurity      = swagger_class.call('definitions', 'oauth2ImplicitSecurity')
    Oauth2PasswordSecurity      = swagger_class.call('definitions', 'oauth2PasswordSecurity')
    Oauth2ApplicationSecurity   = swagger_class.call('definitions', 'oauth2ApplicationSecurity')
    Oauth2AccessCodeSecurity    = swagger_class.call('definitions', 'oauth2AccessCodeSecurity')
    Oauth2Scopes                = swagger_class.call('definitions', 'oauth2Scopes')
    Title                       = swagger_class.call('definitions', 'title')
    Description                 = swagger_class.call('definitions', 'description')
    Default                     = swagger_class.call('definitions', 'default')
    MultipleOf                  = swagger_class.call('definitions', 'multipleOf')
    Maximum                     = swagger_class.call('definitions', 'maximum')
    ExclusiveMaximum            = swagger_class.call('definitions', 'exclusiveMaximum')
    Minimum                     = swagger_class.call('definitions', 'minimum')
    ExclusiveMinimum            = swagger_class.call('definitions', 'exclusiveMinimum')
    MaxLength                   = swagger_class.call('definitions', 'maxLength')
    MinLength                   = swagger_class.call('definitions', 'minLength')
    Pattern                     = swagger_class.call('definitions', 'pattern')
    MaxItems                    = swagger_class.call('definitions', 'maxItems')
    MinItems                    = swagger_class.call('definitions', 'minItems')
    UniqueItems                 = swagger_class.call('definitions', 'uniqueItems')
    Enum                        = swagger_class.call('definitions', 'enum')
    JsonReference               = swagger_class.call('definitions', 'jsonReference')

    class Operation
      attr_accessor :path
      attr_accessor :http_method

      # there should only be one body parameter; this returns it
      def body_parameter
        (parameters || []).detect do |parameter|
          parameter['in'] == 'body'
        end
      end
    end
  end
end
