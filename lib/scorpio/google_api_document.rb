require 'api_hammer/ycomb'
require 'scorpio/schema_object_base'
require 'scorpio/swagger'

module Scorpio
  module Google
    apidoc_schema_doc = ::JSON.parse(Scorpio.root.join('documents/www.googleapis.com/discovery/v1/apis/discovery/v1/rest').read)
    api_document_class = proc do |*key|
      Scorpio.class_for_schema(Scorpio::JSON::Node.new_by_type(apidoc_schema_doc, ['schemas', *key]))
    end

    # naming these is not strictly necessary, but is nice to have.
    # generated: puts Scorpio::Google::ApiDocument.document['schemas'].select { |k,v| v['type'] == 'object' }.keys.map { |k| "#{k[0].upcase}#{k[1..-1]} = api_document_class.call('#{k}')" }
    DirectoryList   = api_document_class.call('DirectoryList')
    JsonSchema      = api_document_class.call('JsonSchema')
    RestDescription = api_document_class.call('RestDescription')
    RestMethod      = api_document_class.call('RestMethod')
    RestResource    = api_document_class.call('RestResource')

    # not generated
    RestMethodRequest = api_document_class.call('RestMethod', 'properties', 'request')
    RestMethodResponse = api_document_class.call('RestMethod', 'properties', 'response')

    # google does a weird thing where it defines a schema with a $ref property where a json-schema is to be used in the document (method request and response fields), instead of just setting the schema to be the json-schema schema. we'll share a module across those schema classes that really represent schemas. is this confusingly meta enough?
    module SchemaLike
      def to_swagger
        dup_doc = ::JSON.parse(::JSON.generate(object.content))
        # swagger does not want an id field on schemas
        dup_doc.delete('id')
        if dup_doc['properties'].is_a?(Hash)
          required_properties = dup_doc['properties'].select do |key, value|
            value.is_a?(Hash) ? value.delete('required') : nil
          end.keys
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
    [JsonSchema, RestMethodRequest, RestMethodResponse].each { |klass| klass.send(:include, SchemaLike) }

    class RestDescription
      def to_swagger_document(options = {})
        Swagger::Document.new(to_swagger_hash(options))
      end

      def to_swagger_hash(options = {})
        # we will be modifying the api document (RestDescription). clone self and modify that one.
        ad = self.class.new(::JSON.parse(::JSON.generate(object.document)))
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
              #operation['tags'] = []
              #operation['summary'] = 
              operation['description'] = method['description'] if method['description']
              if method.resource_name && options[:x]
                operation['x-resource'] = method.resource_name
                operation['x-resource-method'] = method.method_name
              end
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
                    op_param['format'] = parameter.format if parameter.format
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

        swagger = {
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
          'host' => ad.rootUrl ? Addressable::URI.parse(ad.rootUrl).host : ad.baseUrl ? Addressable::URI.parse(ad.rootUrl).host : ad.name, # uhh ... got nothin' better 
          'basePath' => begin
            path = ad.servicePath || ad.basePath || (ad.baseUrl ? Addressable::URI.parse(ad.baseUrl).path : '/')
            path =~ %r(\A/) ? path : "/" + path
          end,
          'schemes' => ad.rootUrl ? [Addressable::URI.parse(ad.rootUrl).scheme] : ad.baseUrl ? [Addressable::URI.parse(ad.rootUrl).scheme] : [], #/definitions/schemesList
          'consumes' => ['application/json'], # we'll just make this assumption
          'produces' => ['application/json'],
          'paths' => paths, #/definitions/paths
        }
        if ad.schemas
          swagger['definitions'] = ad.schemas
          ad.schemas.each do |name, schema|
            swagger = ycomb do |rec|
              proc do |object|
                if object.respond_to?(:to_hash)
                  object.merge(object.map do |k, v|
                    if k == '$ref' && (v == schema['id'] || v == "#/schemas/#{name}" || v == name)
                      {k => "#/definitions/#{name}"}
                    else
                      ycomb do |toswaggerrec|
                        proc do |toswaggerobject|
                          toswaggerobject = toswaggerobject.to_swagger if toswaggerobject.respond_to?(:to_swagger)
                          if toswaggerobject.respond_to?(:to_hash)
                            toswaggerobject.map { |k, v| {toswaggerrec.call(k) => toswaggerrec.call(v)} }.inject({}, &:update)
                          elsif toswaggerobject.respond_to?(:to_ary)
                            toswaggerobject.map(&toswaggerrec)
                          elsif toswaggerobject.is_a?(Symbol)
                            toswaggerobject.to_s
                          elsif [String, TrueClass, FalseClass, NilClass, Numeric].any? { |c| toswaggerobject.is_a?(c) }
                            toswaggerobject
                          else
                            raise(TypeError, "bad (not jsonifiable) object: #{toswaggerobject.pretty_inspect}")
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
            end.call(swagger)
          end
        end
        # check we haven't got anything that shouldn't go in a swagger document
        swagger = ycomb do |rec|
          proc do |object|
            object = object.to_swagger if object.respond_to?(:to_swagger)
            if object.respond_to?(:to_hash)
              object.map { |k, v| {rec.call(k) => rec.call(v)} }.inject({}, &:update)
            elsif object.respond_to?(:to_ary)
              object.map(&rec)
            elsif object.is_a?(Symbol)
              object.to_s
            elsif [String, TrueClass, FalseClass, NilClass, Numeric].any? { |c| object.is_a?(c) }
              object
            else
              raise(TypeError, "bad (not jsonifiable) object: #{object.pretty_inspect}")
            end
          end
        end.call(swagger)
      end
    end
  end
end
