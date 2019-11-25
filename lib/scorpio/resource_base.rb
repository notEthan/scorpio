module Scorpio
  # see also Faraday::Env::MethodsWithBodies
  METHODS_WITH_BODIES = %w(post put patch options)
  class RequestSchemaFailure < Error
  end

  class ResourceBase
    class << self
      # a hash of accessor names (Symbol) to default getter methods (UnboundMethod), used to determine
      # what accessors have been overridden from their defaults.
      (-> (x) { define_method(:inheritable_accessor_defaults) { x } }).({})
      def define_inheritable_accessor(accessor, options = {})
        if options[:default_getter]
          # the value before the field is set (overwritten) is the result of the default_getter proc
          define_singleton_method(accessor, &options[:default_getter])
        else
          # the value before the field is set (overwritten) is the default_value (which is nil if not specified)
          default_value = options[:default_value]
          define_singleton_method(accessor) { default_value }
        end
        inheritable_accessor_defaults[accessor] = self.singleton_class.instance_method(accessor)
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
      openapi_document.base_url(server: server, server_variables: server_variables)
    })

    define_inheritable_accessor(:server_variables, default_value: {}, on_set: -> {
      if openapi_document && openapi_document.v2?
        raise(ArgumentError, "server variables are not supported for OpenAPI V2")
      end
    })

    define_inheritable_accessor(:server, on_set: -> {
      if openapi_document && openapi_document.v2?
        raise(ArgumentError, "servers are not supported for OpenAPI V2")
      end
      unless server.is_a?(Scorpio::OpenAPI::V3::Server)
        raise(TypeError, "server must be an #{Scorpio::OpenAPI::V3::Server.inspect}. received: #{server.pretty_inspect.chomp}")
      end
    })

    define_inheritable_accessor(:user_agent, default_getter: -> { openapi_document.user_agent })

    define_inheritable_accessor(:faraday_builder, default_getter: -> { openapi_document.faraday_builder })
    define_inheritable_accessor(:faraday_adapter, default_getter: -> { openapi_document.faraday_adapter })
    class << self
      # the openapi document
      def openapi_document
        nil
      end
      def openapi_document_class
        nil
      end

      def openapi_document=(openapi_document)
        openapi_document = OpenAPI::Document.from_instance(openapi_document)

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
        # TODO blame validate openapi_document
        update_dynamic_methods
      end

      def tag_name
        nil
      end

      def tag_name=(tag_name)
        unless tag_name.respond_to?(:to_str)
          raise(TypeError, "tag_name must be a string; got: #{tag_name.inspect}")
        end
        tag_name = tag_name.to_str

        begin
          singleton_class.instance_exec { remove_method(:tag_name) }
        rescue NameError
        end
        define_singleton_method(:tag_name) { tag_name }
        define_singleton_method(:tag_name=) do |tag_name|
          unless tag_name == self.tag_name
            raise(ArgumentError, "tag_name may not be overridden (to #{tag_name.inspect}). it is been set to #{self.tag_name.inspect}")
          end
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

        if (operation.request_schemas || []).any? { |s| represented_schemas.include?(s) }
          return true
        end

        return false
      end

      def operation_for_resource_instance?(operation)
        return false unless operation_for_resource_class?(operation)

        # define an instance method if the request schema is for this model 
        request_resource_is_self = operation.request_schemas.any? do |request_schema|
          represented_schemas.include?(request_schema)
        end

        # also define an instance method depending on certain attributes the request description 
        # might have in common with the model's schema attributes
        request_attributes = []
        # if the path has attributes in common with model schema attributes, we'll define on 
        # instance method
        request_attributes |= operation.path_template.variables
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

            # if Pet is the Scorpio resource class
            # and Pet.tag_name is "pet"
            # and operation's operationId is "pet.add"
            # then the operation's method name on Pet will be "add".
            # if the operationId is just "addPet"
            # then the operation's method name on Pet will be "addPet".
            tag_name_match = tag_name &&
              operation.tags.respond_to?(:to_ary) && # TODO maybe operation.tags.valid?
              operation.tags.include?(tag_name) &&
              operation.operationId &&
              operation.operationId.match(/\A#{Regexp.escape(tag_name)}\.(\w+)\z/)

            if tag_name_match
              method_name = tag_name_match[1]
            else
              method_name = operation.operationId
            end
          end
        end
      end

      def update_class_and_instance_api_methods
        openapi_document.paths.each do |path, path_item|
          path_item.each do |http_method, operation|
            next unless operation.is_a?(Scorpio::OpenAPI::Operation)
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

      def call_operation(operation, call_params: nil, model_attributes: nil)
        call_params = JSI.stringify_symbol_keys(call_params) if call_params.respond_to?(:to_hash)
        model_attributes = JSI.stringify_symbol_keys(model_attributes || {})

        request = Scorpio::Request.new(operation)

        accessor_overridden = -> (accessor) do
          # an accessor is overridden if the default accessor getter (UnboundMethod) is the same
          # as the UnboundMethod returned from instance_method on the owner of that instance method.
          # gotta be the owner since different classes return different UnboundMethod instances for
          # the same method. for example, referring to models of scorpio/test/blog_scorpio_models.rb
          # with the server_variables instance method:
          #    Article.instance_method(:server_variables)
          #    => #<UnboundMethod: #<Class:Article>#server_variables>
          # returns a different UnboundMethod than
          #    Scorpio::ResourceBase.instance_method(:server_variables)
          #    => #<UnboundMethod: #<Class:Scorpio::ResourceBase>#server_variables>
          # even though they are really the same method (the #owner for both is Scorpio::ResourceBase)
          inheritable_accessor_defaults[accessor] != self.singleton_class.instance_method(accessor).owner.instance_method(accessor)
        end

        # pretty ugly... may find a better way to do this.
        request.base_url =        self.base_url        if accessor_overridden.(:base_url)
        request.server_variables = self.server_variables if accessor_overridden.(:server_variables)
        request.server =          self.server          if accessor_overridden.(:server)
        request.user_agent =      self.user_agent      if accessor_overridden.(:user_agent)
        request.faraday_builder = self.faraday_builder if accessor_overridden.(:faraday_builder)
        request.faraday_adapter = self.faraday_adapter if accessor_overridden.(:faraday_adapter)

        request.path_params = request.path_template.variables.map do |var|
          if call_params.respond_to?(:to_hash) && call_params.key?(var)
            {var => call_params[var]}
          elsif model_attributes.respond_to?(:to_hash) && model_attributes.key?(var)
            {var => model_attributes[var]}
          else
            {}
          end
        end.inject({}, &:update)

        # assume that call_params must be included somewhere. model_attributes are a source of required things
        # but not required to be here.
        if call_params.respond_to?(:to_hash)
          unused_call_params = call_params.reject { |k, _| request.path_template.variables.include?(k) }
          if !unused_call_params.empty?
            other_params = unused_call_params
          else
            other_params = nil
          end
        else
          other_params = call_params
        end

        if operation.request_schema
          # TODO deal with model_attributes / call_params better in nested whatever
          if call_params.nil?
            request.body_object = request_body_for_schema(model_attributes, operation.request_schema)
          elsif call_params.respond_to?(:to_hash)
            body = request_body_for_schema(model_attributes.merge(call_params), operation.request_schema)
            request.body_object = body.merge(call_params) # TODO
          else
            request.body_object = call_params
          end
        else
          if other_params
            if METHODS_WITH_BODIES.any? { |m| m.to_s == operation.http_method.downcase.to_s }
              request.body_object = other_params
            else
              if other_params.respond_to?(:to_hash)
                # TODO pay more attention to 'parameters' api method attribute
                request.query_params = other_params
              else
                raise
              end
            end
          end
        end

        ur = request.run_ur

        ur.raise_on_http_error

        initialize_options = {
          'persisted' => true,
          'source' => {'operationId' => operation.operationId, 'call_params' => call_params, 'url' => ur.request.uri.to_s},
          'ur' => ur,
        }
        response_object_to_instances(ur.response.body_object, initialize_options)
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
          if object.respond_to?(:to_hash)
            object.map do |key, value|
              if schema
                if schema['type'] == 'object'
                  # TODO code dup with response_object_to_instances
                  if schema['properties'].respond_to?(:to_hash) && schema['properties'].key?(key)
                    subschema = schema['properties'][key]
                    include_pair = true
                  else
                    if schema['patternProperties'].respond_to?(:to_hash)
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
                      elsif [nil, true].include?(schema['additionalProperties'])
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
          elsif object.respond_to?(:to_ary) || object.is_a?(Set)
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
          out = JSI::Typelike.modified_copy(object) do |_object|
            mod = object.map do |key, value|
              {key => response_object_to_instances(value, initialize_options)}
            end.inject({}, &:update)
            mod = mod.instance if mod.is_a?(JSI::Base)
            mod = mod.content if mod.is_a?(JSI::JSON::Node)
            mod
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
      if @options['ur'].is_a?(Scorpio::Ur)
        response_schema = @options['ur'].response.response_schema
      end
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
