# frozen_string_literal: true

module Scorpio
  class RequestSchemaFailure < Error
  end

  class ResourceBase
    class << self
      # ResourceBase.inheritable_accessor_defaults is a hash of accessor names (Symbol) mapped 
      # to default getter methods (UnboundMethod), used to determine what accessors have been
      # overridden from their defaults.
      (-> (x) { define_method(:inheritable_accessor_defaults) { x } }).({})

      # @param accessor [String, Symbol] the name of the accessor
      # @param default_getter [#to_proc] a proc to provide a default value when no value
      #   has been explicitly set
      # @param default_value [Object] a default value to return when no value has been
      #   explicitly set. do not pass both :default_getter and :default_value.
      # @param on_set [#to_proc] callback proc, invoked when a value is assigned
      def define_inheritable_accessor(accessor, default_value: nil, default_getter: -> { default_value }, on_set: nil)
        # the value before the field is set (overwritten) is the result of the default_getter proc
        define_singleton_method(accessor, &default_getter)
        inheritable_accessor_defaults[accessor] = singleton_class.instance_method(accessor)
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
            if on_set
              klass.instance_exec(&on_set)
            end
          end
        end
      end
    end
    define_inheritable_accessor(:represented_schemas, default_value: Set[].freeze, on_set: proc do
      if represented_schemas.is_a?(JSI::SchemaSet)
        represented_schemas.each do |schema|
          new_mbs = openapi_document_class.models_by_schema.merge(schema => self).freeze
          openapi_document_class.models_by_schema = new_mbs
        end
        update_dynamic_methods
      else
        self.represented_schemas = JSI::SchemaSet.ensure_schema_set(represented_schemas)
      end
    end)
    define_inheritable_accessor(:models_by_schema, default_value: {}.freeze)
    # a model overriding this MUST include the openapi document's basePath if defined, e.g.
    # class MyModel
    #   self.base_url = File.join('https://example.com/', openapi_document.basePath)
    # end
    define_inheritable_accessor(:base_url, default_getter: -> {
      openapi_document.base_url(server: server, server_variables: server_variables)
    })

    define_inheritable_accessor(:server_variables, default_value: {}.freeze, on_set: -> {
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
            raise(ArgumentError, "openapi_document may only be set once on #{inspect}")
          else
            raise(ArgumentError, "openapi_document may not be overridden on subclass #{inspect} after it was set on #{openapi_document_class.inspect}")
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
        represented_schemas.map(&:described_object_property_names).inject(Set.new, &:merge)
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
        return true if tag_name && operation.tags.respond_to?(:to_ary) && operation.tags.include?(tag_name)

        request_response_schemas = operation.request_schemas | operation.response_schemas
        # TODO/FIX nil instance is wrong. works for $ref and allOf, not for others.
        # use all inplace applicators, not conditional on instance
        all_request_response_schemas = request_response_schemas.each_inplace_applicator_schema(nil)
        return true if all_request_response_schemas.any? { |s| represented_schemas.include?(s) }

        return false
      end

      def operation_for_resource_instance?(operation)
        return false unless operation_for_resource_class?(operation)

        # define an instance method if the operation's request schemas include any of our represented_schemas
        #
        # TODO/FIX nil instance is wrong. works for $ref and allOf, not for others.
        # use all inplace applicators, not conditional on instance
        all_request_schemas = operation.request_schemas.each_inplace_applicator_schema(nil)
        return true if all_request_schemas.any? { |s| represented_schemas.include?(s) }

        # the below only apply if the operation has this resource's tag
        return false unless tag_name && operation.tags.respond_to?(:to_ary) && operation.tags.include?(tag_name)

        # define an instance method if path or query params can be filled in from
        # property names described by represented_schemas
        schema_attributes = represented_schemas.map(&:described_object_property_names).inject(Set.new, &:merge)
        operation.inferred_parameters.each do |param|
          if param['in'] == 'path' || param['in'] == 'query'
            if schema_attributes.include?(param['name'])
              return true
            end
          end
        end

        return false
      end

      # @private
      # @param name [String]
      # @return [Scorpio::OpenAPI::Operation, nil]
      def operation_for_api_method_name(name)
        openapi_document.operations.detect do |op|
          operation_for_resource_class?(op) && api_method_name_by_operation(op) == name
        end
      end

      # @private
      # @param name [Scorpio::OpenAPI::Operation]
      # @return [String, nil]
      def api_method_name_by_operation(operation)
        raise(ArgumentError, operation.pretty_inspect) unless operation.is_a?(Scorpio::OpenAPI::Operation)

        # if Pet is the Scorpio resource class
        # and Pet.tag_name is "pet"
        # and operation's operationId is "pet.add" or "pet/add" or "pet:add"
        # then the operation's method name on Pet will be "add".
        # if the operationId is just "addPet"
        # then the operation's method name on Pet will be "addPet".
        tag_name_match = tag_name &&
          operation.tags.respond_to?(:to_ary) && # TODO maybe operation.tags.valid?
          operation.tags.include?(tag_name) &&
          operation.operationId &&
          operation.operationId.match(/\A#{Regexp.escape(tag_name)}[\.\/\:](\w+)\z/)

        if tag_name_match
          tag_name_match[1]
        else
          operation.operationId
        end
      end

      def update_class_and_instance_api_methods
        openapi_document.paths.each do |path, path_item|
          path_item.each do |http_method, operation|
            next unless operation.is_a?(Scorpio::OpenAPI::Operation)
            method_name = api_method_name_by_operation(operation)
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
        call_params = JSI::Util.stringify_symbol_keys(call_params) if call_params.respond_to?(:to_hash)
        model_attributes = JSI::Util.stringify_symbol_keys(model_attributes || {})

        request = operation.build_request

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
          inheritable_accessor_defaults[accessor] != singleton_class.instance_method(accessor).owner.instance_method(accessor)
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
          request_body_for_schema = -> (o) do
            if o.is_a?(JSI::Base)
              # TODO check indicated schemas
              if o.jsi_schemas.include?(operation.request_schema)
                jsi = o
              else
                # TODO maybe better way than reinstantiating another jsi as request_schema
                jsi = operation.request_schema.new_jsi(o.jsi_node_content)
              end
            else
              jsi = operation.request_schema.new_jsi(o)
            end
            jsi.jsi_select_children_leaf_first do |node|
              # we want to specifically reject only nodes described (only) by a false schema.
              # note that for OpenAPI schemas, false is only a valid schema as a value
              # of `additionalProperties`
              node.jsi_schemas.empty? || !node.jsi_schemas.all? { |s| s.schema_content == false }
            end
          end
          # TODO deal with model_attributes / call_params better in nested whatever
          if call_params.nil?
            request.body_object = request_body_for_schema.(model_attributes)
          elsif call_params.respond_to?(:to_hash)
            body = request_body_for_schema.(model_attributes)
            request.body_object = body.merge(call_params) # TODO
          else
            request.body_object = call_params
          end
        else
          if other_params
            if Request.method_with_body?(request.http_method)
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

      def response_object_to_instances(object, initialize_options = {})
        if object.is_a?(JSI::Base)
          models = object.jsi_schemas.map { |schema| models_by_schema[schema] }.compact
          if models.size == 0
            model = nil
          elsif models.size == 1
            model = models.first
          else
            raise(Scorpio::OpenAPI::Error, "multiple models indicated by response JSI. models: #{models.inspect}; object: #{object.pretty_inspect.chomp}")
          end

          if model && object.respond_to?(:to_hash)
            model.new(object, initialize_options)
          else
            Container.new_container(object, openapi_document_class, initialize_options)
          end
        else
          object
        end
      end
    end
  end

  class ResourceBase
    module Containment
      def [](key, _: nil) # unused keyword param lets an empty keyword hash be passed in older ruby versions
        sub = contained_object[key]
        if sub.is_a?(JSI::Base)
          # TODO avoid reinstantiating the container only to throw it away if it matches the memo
          sub_container = @openapi_document_class.response_object_to_instances(sub, options)

          if @subscript_memos.key?(key) && @subscript_memos[key].class == sub_container.class
            @subscript_memos[key]
          else
            @subscript_memos[key] = sub_container
          end
        else
          sub
        end
      end

      def []=(key, value)
        @subscript_memos.delete(key)
        if value.is_a?(Containment)
          contained_object[key] = value.contained_object
        else
          contained_object[key] = value
        end
      end

      def as_json(*opt)
        JSI::Typelike.as_json(contained_object, *opt)
      end

      def inspect
        "\#<#{self.class.inspect} #{contained_object.inspect}>"
      end

      def pretty_print(q)
        q.instance_exec(self) do |obj|
          text "\#<#{obj.class.inspect}"
          group_sub {
            nest(2) {
              breakable ' '
              pp obj.contained_object
            }
          }
          breakable ''
          text '>'
        end
      end

      include JSI::Util::FingerprintHash

      def jsi_fingerprint
        {class: self.class, contained_object: as_json}
      end
    end
  end

  class ResourceBase
    include Containment

    def initialize(attributes = {}, options = {})
      @attributes = JSI::Util.stringify_symbol_keys(attributes)
      @options = JSI::Util.stringify_symbol_keys(options)
      @persisted = !!@options['persisted']

      @openapi_document_class = self.class.openapi_document_class
      @subscript_memos = {}
    end

    attr_reader :attributes
    attr_reader :options

    alias_method :contained_object, :attributes

    def persisted?
      @persisted
    end

    def call_api_method(method_name, call_params: nil)
      operation = self.class.operation_for_api_method_name(method_name) || raise(ArgumentError)
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
  end

  class ResourceBase
    class Container
      @container_classes = Hash.new do |h, modules|
        container_class = Class.new(Container)
        modules.each do |mod|
          container_class.include(mod)
        end
        h[modules] = container_class
      end

      class << self
        def new_container(object, openapi_document_class, options = {})
          container_modules = Set[]

          # TODO this is JSI internals that scorpio shouldn't really be using
          if object.respond_to?(:to_hash)
            container_modules << JSI::Base::HashNode
          end
          if object.respond_to?(:to_ary)
            container_modules << JSI::Base::ArrayNode
          end

          container_modules += object.jsi_schemas.map do |schema|
            JSI::SchemaClasses.accessor_module_for_schema(schema,
              conflicting_modules: container_modules + [Container],
            )
          end

          container_class = @container_classes[container_modules.freeze]

          container_class.new(object, openapi_document_class, options)
        end
      end
    end

    class Container
      include Containment

      def initialize(contained_object, openapi_document_class, options = {})
        @contained_object = contained_object
        @openapi_document_class = openapi_document_class
        @options = options
        @subscript_memos = {}
      end

      attr_reader :contained_object

      attr_reader :options

      # @private
      alias_method :jsi_node_content, :contained_object
      private :jsi_node_content

      # @private
      # @return [Array<String>]
      def jsi_object_group_text
        schema_names = contained_object.jsi_schemas.map { |schema| schema.jsi_schema_module.name_from_ancestor || schema.schema_uri }.compact
        if schema_names.empty?
          [Container.to_s]
        else
          ["#{Container} (#{schema_names.join(', ')})"]
        end
      end
    end
  end
end
