require 'addressable/template'
require 'faraday'
require 'scorpio/util/faraday/response_media_type'

module Scorpio
  # see also Faraday::Env::MethodsWithBodies
  METHODS_WITH_BODIES = %w(post put patch options)
  class RequestSchemaFailure < Error
  end

  class ResourceBase
    class << self
      def define_inheritable_accessor(accessor, options = {})
        if options[:default_getter]
          # the value before the field is set (overwritten) is the result of the default_getter proc
          define_singleton_method(accessor, &options[:default_getter])
        else
          # the value before the field is set (overwritten) is the default_value (which is nil if not specified)
          default_value = options[:default_value]
          define_singleton_method(accessor) { default_value }
        end
        # field setter method. redefines the getter, replacing the method with one that returns the
        # setter's argument (that being inherited to the scope of the define_method(accessor) block
        define_singleton_method(:"#{accessor}=") do |value|
          # the setter operates on the singleton class of the receiver (self)
          singleton_class.instance_exec(value, self) do |value_, klass|
            # remove a previous getter. NameError is raised if a getter is not defined on this class;
            # this may be ignored.
            begin
              remove_method(accessor)
            rescue NameError
            end
            # getter method
            define_method(accessor) { value_ }
            # invoke on_set callback defined on the class
            if options[:on_set]
              klass.instance_exec(&options[:on_set])
            end
          end
        end
      end
    end
    define_inheritable_accessor(:represented_schemas, default_value: [], on_set: proc do
      unless represented_schemas.respond_to?(:to_ary)
        raise(TypeError, "represented_schemas must be an array. received: #{represented_schemas.pretty_inspect.chomp}")
      end
      if represented_schemas.all? { |s| s.is_a?(JSI::Schema) }
        represented_schemas.each do |schema|
          openapi_document_class.models_by_schema = openapi_document_class.models_by_schema.merge(schema => self)
        end
        update_dynamic_methods
      else
        self.represented_schemas = self.represented_schemas.map do |schema|
          unless schema.is_a?(JSI::Schema)
            schema = JSI::Schema.new(schema)
          end
          schema
        end
      end
    end)
    define_inheritable_accessor(:models_by_schema, default_value: {})
    # a model overriding this MUST include the openapi document's basePath if defined, e.g.
    # class MyModel
    #   self.base_url = File.join('https://example.com/', openapi_document.basePath)
    # end
    define_inheritable_accessor(:base_url, default_getter: -> {
      openapi_document.base_url
    })

    define_inheritable_accessor(:user_agent, default_getter: -> { openapi_document.user_agent })

    define_inheritable_accessor(:faraday_request_middleware, default_value: [])
    define_inheritable_accessor(:faraday_adapter, default_getter: proc { Faraday.default_adapter })
    define_inheritable_accessor(:faraday_response_middleware, default_value: [])
    class << self
      # the openapi document
      def openapi_document
        nil
      end
      def openapi_document_class
        nil
      end

      def openapi_document=(openapi_document)
        if openapi_document.is_a?(Hash)
          openapi_document = JSI::JSON::Node.new_doc(openapi_document)
        end
        if openapi_document.is_a?(JSI::JSON::Node)
          if openapi_document['swagger'] =~ /\A2(\.|\z)/
            openapi_document = Scorpio::OpenAPI::V2::Document.new(openapi_document)
          elsif openapi_document['openapi'] =~ /\A3(\.|\z)/
            openapi_document = Scorpio::OpenAPI::V3::Document.new(openapi_document)
          end
        end
        unless openapi_document.is_a?(OpenAPI::Document)
          raise(TypeError)
        end

        begin
          singleton_class.instance_exec { remove_method(:openapi_document) }
        rescue NameError
        end
        begin
          singleton_class.instance_exec { remove_method(:openapi_document_class) }
        rescue NameError
        end
        openapi_document_class = self
        define_singleton_method(:openapi_document) { openapi_document }
        define_singleton_method(:openapi_document_class) { openapi_document_class }
        define_singleton_method(:openapi_document=) do |_|
          if self == openapi_document_class
            raise(ArgumentError, "openapi_document may only be set once on #{self.inspect}")
          else
            raise(ArgumentError, "openapi_document may not be overridden on subclass #{self.inspect} after it was set on #{openapi_document_class.inspect}")
          end
        end
        update_dynamic_methods

        openapi_document.paths.each do |path, path_item|
          path_item.each do |http_method, operation|
            unless operation.is_a?(Scorpio::OpenAPI::Operation)
              next
            end
          end
        end

        # TODO blame validate openapi_document

        update_dynamic_methods
      end

      def tag_name
        nil
      end

      def tag_name=(tag_name)
        unless tag_name.respond_to?(:to_str)
          raise(TypeError)
        end
        set_on_class = self
        tag_name = tag_name.to_str

        begin
          singleton_class.instance_exec { remove_method(:tag_name) }
        rescue NameError
        end
        define_singleton_method(:tag_name) { tag_name }
        define_singleton_method(:tag_name=) do |_|
          raise(ArgumentError, "tag_name may not be overridden. it is been set to #{tag_name.inspect}")
        end
        update_dynamic_methods
      end

      def update_dynamic_methods
        update_class_and_instance_api_methods
        update_instance_accessors
      end

      def all_schema_properties
        represented_schemas.map(&:described_object_property_names).inject(Set.new, &:|)
      end

      def update_instance_accessors
        all_schema_properties.each do |property_name|
          unless method_defined?(property_name)
            define_method(property_name) do
              self[property_name]
            end
          end
          unless method_defined?(:"#{property_name}=")
            define_method(:"#{property_name}=") do |value|
              self[property_name] = value
            end
          end
        end
      end

      def operation_for_resource_class?(operation)
        return false unless tag_name

        return true if operation.tags.respond_to?(:to_ary) && operation.tags.include?(tag_name)

        if operation.request_schema && represented_schemas.include?(operation.request_schema)
          return true
        end

        return false
      end

      def operation_for_resource_instance?(operation)
        return false unless operation_for_resource_class?(operation)

        # define an instance method if the request schema is for this model 
        request_resource_is_self = operation.request_schema && represented_schemas.include?(operation.request_schema)

        # also define an instance method depending on certain attributes the request description 
        # might have in common with the model's schema attributes
        request_attributes = []
        # if the path has attributes in common with model schema attributes, we'll define on 
        # instance method
        request_attributes |= Addressable::Template.new(operation.path).variables
        # TODO if the method request schema has attributes in common with the model schema attributes,
        # should we define an instance method?
        #request_attributes |= request_schema && request_schema['type'] == 'object' && request_schema['properties'] ?
        #  request_schema['properties'].keys : []
        # TODO if the method parameters have attributes in common with the model schema attributes,
        # should we define an instance method?
        #request_attributes |= method_desc['parameters'] ? method_desc['parameters'].keys : []

        schema_attributes = represented_schemas.map(&:described_object_property_names).inject(Set.new, &:|)

        return request_resource_is_self || (request_attributes & schema_attributes.to_a).any?
      end

      def method_names_by_operation
        @method_names_by_operation ||= Hash.new do |h, operation|
          h[operation] = begin
            raise(ArgumentError, operation.pretty_inspect) unless operation.is_a?(Scorpio::OpenAPI::Operation)

            if operation.tags.respond_to?(:to_ary) && operation.tags.include?(tag_name) && operation.operationId =~ /\A#{Regexp.escape(tag_name)}\.(\w+)\z/
              method_name = $1
            else
              method_name = operation.operationId
            end
          end
        end
      end

      def update_class_and_instance_api_methods
        openapi_document.paths.each do |path, path_item|
          path_item.each do |http_method, operation|
            next if http_method == 'parameters' # parameters is not an operation. TOOD maybe just select the keys that are http methods?
            method_name = method_names_by_operation[operation]
            if method_name
              # class method
              if operation_for_resource_class?(operation) && !respond_to?(method_name)
                define_singleton_method(method_name) do |call_params = nil|
                  call_operation(operation, call_params: call_params)
                end
              end

              # instance method
              if operation_for_resource_instance?(operation) && !method_defined?(method_name)
                define_method(method_name) do |call_params = nil|
                  call_operation(operation, call_params: call_params)
                end
              end
            end
          end
        end
      end

      def connection
        Faraday.new(:headers => {'User-Agent' => user_agent}) do |c|
          faraday_request_middleware.each do |m|
            c.request(*m)
          end
          faraday_response_middleware.each do |m|
            c.response(*m)
          end
          c.adapter(*faraday_adapter)
        end
      end

      def call_operation(operation, call_params: nil, model_attributes: nil)
        call_params = JSI.stringify_symbol_keys(call_params) if call_params.is_a?(Hash)
        model_attributes = JSI.stringify_symbol_keys(model_attributes || {})
        http_method = operation.http_method.downcase.to_sym
        path_template = Addressable::Template.new(operation.path)
        template_params = model_attributes
        template_params = template_params.merge(call_params) if call_params.is_a?(Hash)
        missing_variables = path_template.variables - template_params.keys
        if missing_variables.any?
          raise(ArgumentError, "path #{operation.path} for operation #{operation.operationId} requires attributes " +
            "which were missing: #{missing_variables.inspect}")
        end
        empty_variables = path_template.variables.select { |v| template_params[v].to_s.empty? }
        if empty_variables.any?
          raise(ArgumentError, "path #{operation.path} for operation #{operation.operationId} requires attributes " +
            "which were empty: #{empty_variables.inspect}")
        end
        path = path_template.expand(template_params)
        # we do not use Addressable::URI#join as the paths should just be concatenated, not resolved.
        # we use File.join just to deal with consecutive slashes.
        url = File.join(base_url, path)
        url = Addressable::URI.parse(url)
        # assume that call_params must be included somewhere. model_attributes are a source of required things
        # but not required to be here.
        other_params = call_params
        if other_params.is_a?(Hash)
          other_params.reject! { |k, _| path_template.variables.include?(k) }
        end

        if operation.request_schema
          # TODO deal with model_attributes / call_params better in nested whatever
          if call_params.nil?
            body = request_body_for_schema(model_attributes, operation.request_schema)
          elsif call_params.is_a?(Hash)
            body = request_body_for_schema(model_attributes.merge(call_params), operation.request_schema)
            body = body.merge(call_params) # TODO
          else
            body = call_params
          end
        else
          if other_params
            if METHODS_WITH_BODIES.any? { |m| m.to_s == http_method.downcase.to_s }
              body = other_params
            else
              if other_params.is_a?(Hash)
                # TODO pay more attention to 'parameters' api method attribute
                url.query_values = other_params
              else
                raise
              end
            end
          end
        end

        request_headers = {}

        if METHODS_WITH_BODIES.any? { |m| m.to_s == http_method.downcase.to_s } && body != nil
          consumes = operation.consumes || openapi_document.consumes || []
          if consumes.include?("application/json") || (!body.respond_to?(:to_str) && consumes.empty?)
          # if we have a body that's not a string and no indication of how to serialize it, we guess json.
            request_headers['Content-Type'] = "application/json"
            unless body.respond_to?(:to_str)
              body = ::JSON.pretty_generate(JSI::Typelike.as_json(body))
            end
          elsif consumes.include?("application/x-www-form-urlencoded")
            request_headers['Content-Type'] = "application/x-www-form-urlencoded"
            unless body.respond_to?(:to_str)
              body = URI.encode_www_form(body)
            end
          elsif body.is_a?(String)
            if consumes.size == 1
              request_headers['Content-Type'] = consumes.first
            end
          else
            raise("do not know how to serialize for #{consumes.inspect}: #{body.pretty_inspect.chomp}")
          end
        end

        response = connection.run_request(http_method, url, body, request_headers)

        if response.media_type == 'application/json'
          if response.body.empty?
            response_object = nil
          else
            begin
              response_object = ::JSON.parse(response.body)
            rescue ::JSON::ParserError
              # TODO warn
              response_object = response.body
            end
          end
        else
          response_object = response.body
        end

        if operation.responses
          _, operation_response = operation.responses.detect { |k, v| k.to_s == response.status.to_s }
          operation_response ||= operation.responses['default']
          response_schema = operation_response['schema'] if operation_response
        end
        if response_schema
          # not too sure about this, but I don't think it makes sense to instantiate things that are
          # not hash or array as a JSI
          if response_object.respond_to?(:to_hash) || response_object.respond_to?(:to_ary)
            response_object = JSI.class_for_schema(response_schema).new(response_object)
          end
        end

        error_class = Scorpio.error_classes_by_status[response.status]
        error_class ||= if (400..499).include?(response.status)
          ClientError
        elsif (500..599).include?(response.status)
          ServerError
        elsif !response.success?
          HTTPError
        end
        if error_class
          message = "Error calling operation #{operation.operationId} on #{self}:\n" + (response.env[:raw_body] || response.env.body)
          raise(error_class.new(message).tap do |e|
            e.faraday_response = response
            e.response_object = response_object
          end)
        end

        initialize_options = {
          'persisted' => true,
          'source' => {'operationId' => operation.operationId, 'call_params' => call_params, 'url' => url.to_s},
          'response' => response,
        }
        response_object_to_instances(response_object, initialize_options)
      end

      def request_body_for_schema(object, schema)
        if object.is_a?(Scorpio::ResourceBase)
          # TODO request_schema_fail unless schema is for given model type 
          request_body_for_schema(object.attributes, schema)
        elsif object.is_a?(JSI::Base)
          request_body_for_schema(object.instance, schema)
        elsif object.is_a?(JSI::JSON::Node)
          request_body_for_schema(object.content, schema)
        else
          if object.is_a?(Hash)
            object.map do |key, value|
              if schema
                if schema['type'] == 'object'
                  # TODO code dup with response_object_to_instances
                  if schema['properties'] && schema['properties'][key]
                    subschema = schema['properties'][key]
                    include_pair = true
                  else
                    if schema['patternProperties']
                      _, pattern_schema = schema['patternProperties'].detect do |pattern, _|
                        key =~ Regexp.new(pattern) # TODO map pattern to ruby syntax
                      end
                    end
                    if pattern_schema
                      subschema = pattern_schema
                      include_pair = true
                    else
                      if schema['additionalProperties'] == false
                        include_pair = false
                      elsif schema['additionalProperties'] == nil
                        # TODO decide on this (can combine with `else` if treating nil same as schema present)
                        include_pair = true
                        subschema = nil
                      else
                        include_pair = true
                        subschema = schema['additionalProperties']
                      end
                    end
                  end
                elsif schema['type']
                  request_schema_fail(object, schema)
                else
                  # TODO not sure
                  include_pair = true
                  subschema = nil
                end
              end
              if include_pair
                {key => request_body_for_schema(value, subschema)}
              else
                {}
              end
            end.inject({}, &:update)
          elsif object.is_a?(Array) || object.is_a?(Set)
            object.map do |el|
              if schema
                if schema['type'] == 'array'
                  # TODO index based subschema or whatever else works for array
                  subschema = schema['items']
                elsif schema['type']
                  request_schema_fail(object, schema)
                end
              end
              request_body_for_schema(el, subschema)
            end
          else
            # TODO maybe raise on anything not serializable 
            # TODO check conformance to schema, request_schema_fail if not
            object
          end
        end
      end

      def request_schema_fail(object, schema)
        # TODO blame
      end

      def response_object_to_instances(object, initialize_options = {})
        if object.is_a?(JSI::Base)
          model = models_by_schema[object.schema]
        end

        if object.respond_to?(:to_hash)
          out = JSI::Typelike.modified_copy(object) do
            object.map do |key, value|
              {key => response_object_to_instances(value, initialize_options)}
            end.inject({}, &:update)
          end
          if model
            model.new(out, initialize_options)
          else
            out
          end
        elsif object.respond_to?(:to_ary)
          JSI::Typelike.modified_copy(object) do
            object.map do |element|
              response_object_to_instances(element, initialize_options)
            end
          end
        else
          object
        end
      end
    end

    def initialize(attributes = {}, options = {})
      @attributes = JSI.stringify_symbol_keys(attributes)
      @options = JSI.stringify_symbol_keys(options)
      @persisted = !!@options['persisted']
    end

    attr_reader :attributes
    attr_reader :options

    def persisted?
      @persisted
    end

    def [](key)
      @attributes[key]
    end

    def []=(key, value)
      @attributes[key] = value
    end

    def call_api_method(method_name, call_params: nil)
      operation = self.class.method_names_by_operation.invert[method_name] || raise(ArgumentError)
      call_operation(operation, call_params: call_params)
    end

    def call_operation(operation, call_params: nil)
      response = self.class.call_operation(operation, call_params: call_params, model_attributes: self.attributes)

      # if we're making a POST or PUT and the request schema is this resource, we'll assume that
      # the request is persisting this resource
      request_resource_is_self = operation.request_schema && self.class.represented_schemas.include?(operation.request_schema)
      if @options['response'] && @options['response'].status && operation.responses
        _, response_schema_node = operation.responses.detect { |k, v| k.to_s == @options['response'].status.to_s }
      end
      response_schema = JSI::Schema.new(response_schema_node) if response_schema_node
      response_resource_is_self = response_schema && self.class.represented_schemas.include?(response_schema)
      if request_resource_is_self && %w(put post).include?(operation.http_method.to_s.downcase)
        @persisted = true

        if response_resource_is_self
          @attributes = response.attributes
        end
      end

      response
    end

    def as_json(*opt)
      JSI::Typelike.as_json(@attributes, *opt)
    end

    def inspect
      "\#<#{self.class.inspect} #{attributes.inspect}>"
    end
    def pretty_print(q)
      q.instance_exec(self) do |obj|
        text "\#<#{obj.class.inspect}"
        group_sub {
          nest(2) {
            breakable ' '
            pp obj.attributes
          }
        }
        breakable ''
        text '>'
      end
    end

    def fingerprint
      {class: self.class, attributes: JSI::Typelike.as_json(@attributes)}
    end
    include JSI::FingerprintHash
  end
end
