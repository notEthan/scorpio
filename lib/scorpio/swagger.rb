require 'scorpio/schema_object_base'

module Scorpio
  module Swagger
    swagger_schema_doc = ::JSON.parse(Scorpio.root.join('documents/swagger.io/v2/schema.json').read)
    swagger_class = proc do |definitions_key|
      Scorpio.class_for_schema(Scorpio::JSON::Node.new_by_type(swagger_schema_doc, ['definitions', definitions_key]))
    end

    Document = Scorpio.class_for_schema(Scorpio::JSON::Node.new_by_type(swagger_schema_doc, []))

    # naming these is not strictly necessary, but is nice to have.
    # generated: puts Scorpio::Swagger::Document.document['definitions'].select { |k,v| v['type'] == 'object' }.keys.map { |k| "#{k[0].upcase}#{k[1..-1]} = swagger_class.call('#{k}')" }
    Info                        = swagger_class.call('info')
    Contact                     = swagger_class.call('contact')
    License                     = swagger_class.call('license')
    Paths                       = swagger_class.call('paths')
    Definitions                 = swagger_class.call('definitions')
    ParameterDefinitions        = swagger_class.call('parameterDefinitions')
    ResponseDefinitions         = swagger_class.call('responseDefinitions')
    ExternalDocs                = swagger_class.call('externalDocs')
    Examples                    = swagger_class.call('examples')
    Operation                   = swagger_class.call('operation')
    PathItem                    = swagger_class.call('pathItem')
    Responses                   = swagger_class.call('responses')
    Response                    = swagger_class.call('response')
    Headers                     = swagger_class.call('headers')
    Header                      = swagger_class.call('header')
    BodyParameter               = swagger_class.call('bodyParameter')
    NonBodyParameter            = swagger_class.call('nonBodyParameter')
    Schema                      = swagger_class.call('schema')
    FileSchema                  = swagger_class.call('fileSchema')
    PrimitivesItems             = swagger_class.call('primitivesItems')
    SecurityRequirement         = swagger_class.call('securityRequirement')
    Xml                         = swagger_class.call('xml')
    Tag                         = swagger_class.call('tag')
    SecurityDefinitions         = swagger_class.call('securityDefinitions')
    BasicAuthenticationSecurity = swagger_class.call('basicAuthenticationSecurity')
    ApiKeySecurity              = swagger_class.call('apiKeySecurity')
    Oauth2ImplicitSecurity      = swagger_class.call('oauth2ImplicitSecurity')
    Oauth2PasswordSecurity      = swagger_class.call('oauth2PasswordSecurity')
    Oauth2ApplicationSecurity   = swagger_class.call('oauth2ApplicationSecurity')
    Oauth2AccessCodeSecurity    = swagger_class.call('oauth2AccessCodeSecurity')
    Oauth2Scopes                = swagger_class.call('oauth2Scopes')
    JsonReference               = swagger_class.call('jsonReference')

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
