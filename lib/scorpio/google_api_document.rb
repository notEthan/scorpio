# frozen_string_literal: true

module Scorpio
  module Google
    discovery_rest_description_doc = JSON.parse(Scorpio.root.join('documents/www.googleapis.com/discovery/v1/apis/discovery/v1/rest').read, freeze: true)
    discovery_rest_description = JSI::MetaSchemaNode.new(
      discovery_rest_description_doc,
      metaschema_root_ptr: JSI::Ptr['schemas']['JsonSchema'],
      root_schema_ptr: JSI::Ptr['schemas']['RestDescription'],
      schema_implementation_modules: [JSI::Schema::Draft04],
    )

    # naming these is not strictly necessary, but is nice to have.
    DirectoryList = discovery_rest_description.schemas['DirectoryList'].jsi_schema_module
    JsonSchema     = discovery_rest_description.schemas['JsonSchema'].jsi_schema_module
    RestDescription = discovery_rest_description.schemas['RestDescription'].jsi_schema_module
    RestMethod     = discovery_rest_description.schemas['RestMethod'].jsi_schema_module
    RestResource  = discovery_rest_description.schemas['RestResource'].jsi_schema_module

    module RestDescription
      Resources = properties['resources']
    end

    module RestMethod
      Request = properties['request']
      Response = properties['response']
    end

    # google does a weird thing where it defines a schema with a $ref property where a json-schema is to be used in the document (method request and response fields), instead of just setting the schema to be the json-schema schema. we'll share a module across those schema classes that really represent schemas. is this confusingly meta enough?
    module SchemaLike
      def to_openapi
        # openapi does not want an id field on schemas
        dup_doc = jsi_node_content.reject { |k, _| k == 'id' }
        if dup_doc['properties'].is_a?(Hash)
          required_properties = []
          dup_doc['properties'].each do |key, value|
            if value.is_a?(Hash) && value.key?('required')
              required_properties.push(key) if value['required']
              dup_doc = dup_doc.merge({'properties' => value.reject { |vk, _| vk == 'required' }})
            end
          end
          # put required before properties
          unless required_properties.empty?
            dup_doc = dup_doc.map do |k, v|
              base = k == 'properties' ? {'required' => required_properties } : {}
              base.merge({k => v})
            end.inject({}, &:update)
          end
        end
        dup_doc
      end
    end
    [JsonSchema, RestMethod::Request, RestMethod::Response].each { |m| m.send(:include, SchemaLike) }

    module RestDescription
      def to_openapi_document(options = {})
        Scorpio::OpenAPI::Document.from_instance(to_openapi_hash(options))
      end

      def to_openapi_hash(options = {})
        ad = self
        ad_methods = []
        if ad['methods']
          ad_methods += ad['methods'].map do |mn, m|
            m.tap do
              m.send(:define_singleton_method, :resource_name) { }
              m.send(:define_singleton_method, :method_name) { mn }
            end
          end
        end
        ad_methods += ad.resources.map do |rn, r|
          (r['methods'] || {}).map do |mn, m|
            m.tap do
              m.send(:define_singleton_method, :resource_name) { rn }
              m.send(:define_singleton_method, :method_name) { mn }
            end
          end
        end.inject([], &:+)

        paths = ad_methods.group_by { |m| m['path'] }.map do |path, path_methods|
          unless path =~ %r(\A/)
            path = '/' + path
          end
          operations = path_methods.group_by { |m| m['httpMethod'] }.map do |http_method, http_method_methods|
            if http_method_methods.size > 1
              #raise("http method #{http_method} at path #{path} not unique: #{http_method_methods.pretty_inspect}")
            end
            method = http_method_methods.first
            unused_path_params = Addressable::Template.new(path).variables
            {http_method.downcase => {}.tap do |operation|
              operation['tags'] = method.resource_name ? [method.resource_name] : []
              #operation['summary'] = 
              operation['description'] = method['description'] if method['description']
              #operation['externalDocs'] = 
              operation['operationId'] = method['id'] || (method.resource_name ? "#{method.resource_name}.#{method.method_name}" : method.method_name)
              #operation['produces'] = 
              #operation['consumes'] = 
              if method['parameters']
                operation['parameters'] = method['parameters'].map do |name, parameter|
                  {}.tap do |op_param|
                    op_param['description'] = parameter.description if parameter.description
                    op_param['name'] = name
                    op_param['in'] = if parameter.location
                      parameter.location
                    elsif unused_path_params.include?(name)
                      'path'
                    else
                      'query'
                    # unused: header, formdata, body
                    end
                    unused_path_params.delete(name) if op_param['in'] == 'path'
                    op_param['required'] = parameter.key?('required') ? parameter['required'] : op_param['in'] == 'path' ? true : false
                    op_param['type'] = parameter.type || 'string'
                    op_param['format'] = parameter['format'] if parameter['format']
                  end
                end
              end
              if unused_path_params.any?
                operation['parameters'] ||= []
                operation['parameters'] += unused_path_params.map do |param_name|
                  {
                    'name' => param_name,
                    'in' => 'path',
                    'required' => true,
                    'type' => 'string',
                  }
                end
              end
              if method['request']
                operation['parameters'] ||= []
                operation['parameters'] << {
                  'name' => 'body',
                  'in' => 'body',
                  'required' => true,
                  'schema' => method['request'],
                }
              end
              if method['response']
                operation['responses'] = {
                  'default' => {
                    'description' => 'default response',
                    'schema' => method['response'],
                  },
                }
              end
            end}
          end.inject({}, &:update)

          {path => operations}
        end.inject({}, &:update)

        openapi = {
          'swagger' => '2.0',
          'info' => { #/definitions/info
            'title' => ad.title || ad.name,
            'description' => ad.description,
            'version' => ad.version || '',
            #'termsOfService' => '',
            'contact' => {
              'name' => ad.ownerName,
              #'url' => 
              #'email' => '',
            }.reject { |_, v| v.nil? },
            #'license' => {
              #'name' => '',
              #'url' => '',
            #},
          },
          'host' => ad.rootUrl ? Addressable::URI.parse(ad.rootUrl).host : ad.baseUrl ? Addressable::URI.parse(ad.baseUrl).host : ad.name, # uhh ... got nothin' better
          'basePath' => begin
            path = ad.servicePath || ad.basePath || (ad.baseUrl ? Addressable::URI.parse(ad.baseUrl).path : '/')
            path =~ %r(\A/) ? path : "/" + path
          end,
          'schemes' => ad.rootUrl ? [Addressable::URI.parse(ad.rootUrl).scheme] : ad.baseUrl ? [Addressable::URI.parse(ad.rootUrl).scheme] : [], #/definitions/schemesList
          'consumes' => ['application/json'], # we'll just make this assumption
          'produces' => ['application/json'],
          'tags' => paths.flat_map { |_, p| p.flat_map { |_, op| (op['tags'] || []).map { |n| {'name' => n} } } }.uniq,
          'paths' => paths, #/definitions/paths
        }
        if ad.schemas
          openapi['definitions'] = ad.schemas
          ad.schemas.each do |name, schema|
            openapi = JSI::Util.ycomb do |rec|
              proc do |object|
                if object.respond_to?(:to_hash)
                  object.merge(object.map do |k, v|
                    if k == '$ref' && (v == schema['id'] || v == "#/schemas/#{name}" || v == name)
                      {k => "#/definitions/#{name}"}
                    else
                      JSI::Util.ycomb do |toopenapirec|
                        proc do |toopenapiobject|
                          toopenapiobject = toopenapiobject.to_openapi if toopenapiobject.respond_to?(:to_openapi)
                          if toopenapiobject.respond_to?(:to_hash)
                            toopenapiobject.map { |k2, v2| {toopenapirec.call(k2) => toopenapirec.call(v2)} }.inject({}, &:update)
                          elsif toopenapiobject.respond_to?(:to_ary)
                            toopenapiobject.map(&toopenapirec)
                          elsif toopenapiobject.is_a?(Symbol)
                            toopenapiobject.to_s
                          elsif [String, TrueClass, FalseClass, NilClass, Numeric].any? { |c| toopenapiobject.is_a?(c) }
                            toopenapiobject
                          else
                            raise(TypeError, "bad (not jsonifiable) object: #{toopenapiobject.pretty_inspect}")
                          end
                        end
                      end.call({k => rec.call(v)})
                    end
                  end.inject({}, &:merge))
                elsif object.respond_to?(:to_ary)
                  object.map(&rec)
                else
                  object
                end
              end
            end.call(openapi)
          end
        end
        JSI::Util.as_json(openapi)
      end
    end
  end
end
