module Scorpio
  class Schema
    def initialize(schema_node)
      @schema_node = schema_node
    end
    attr_reader :schema_node

    def subschema_for_property(property_name)
      if schema_node['properties'].respond_to?(:to_hash) && schema_node['properties'][property_name].respond_to?(:to_hash)
        self.class.new(schema_node['properties'][property_name].deref)
      else
        if schema_node['patternProperties'].respond_to?(:to_hash)
          _, pattern_schema_node = schema_node['patternProperties'].detect do |pattern, _|
            property_name =~ Regexp.new(pattern) # TODO map pattern to ruby syntax
          end
        end
        if pattern_schema_node
          self.class.new(pattern_schema_node.deref)
        else
          if schema_node['additionalProperties']
            self.class.new(schema_node['additionalProperties'].deref)
          else
            nil
          end
        end
      end
    end

    def match_to_object(object)
      %w(oneOf allOf anyOf).select { |k| schema_node[k].respond_to?(:to_ary) }.each do |someof_key|
        schema_node[someof_key].map(&:deref).map do |someof_node|
          someof_schema = self.class.new(someof_node)
          if someof_schema.validate(object)
            return someof_schema.match_to_object(object)
          end
        end
      end
      return self
    end

    def subschema_for_index(index)
      if schema_node['items'].is_a?(JSON::ArrayNode)
        if index < schema_node['items'].size
          self.class.new(schema_node['items'][index])
        elsif schema_node['additionalItems']
          self.class.new(schema_node['additionalItems'])
        end
      elsif schema_node['items']
        self.class.new(schema_node['items'])
      else
        nil
      end
    end

    def describes_array?
      schema_node['type'] == 'array' ||
        schema_node['items'] ||
        schema_node['additionalItems'] ||
        schema_node['default'].respond_to?(:to_ary) || # TODO make sure this is right
        (schema_node['enum'].respond_to?(:to_ary) && schema_node['enum'].all? { |enum| enum.respond_to?(:to_ary) }) ||
        schema_node['maxItems'] ||
        schema_node['minItems'] ||
        schema_node.key?('uniqueItems') ||
        schema_node['oneOf'].respond_to?(:to_ary) &&
          schema_node['oneOf'].all? { |someof_node| self.class.new(someof_node).describes_array? } ||
        schema_node['allOf'].respond_to?(:to_ary) &&
          schema_node['allOf'].all? { |someof_node| self.class.new(someof_node).describes_array? } ||
        schema_node['anyOf'].respond_to?(:to_ary) &&
          schema_node['anyOf'].all? { |someof_node| self.class.new(someof_node).describes_array? }
    end
    def describes_hash?
      schema_node['type'] == 'object' ||
        schema_node['required'].respond_to?(:to_ary) ||
        schema_node['properties'].respond_to?(:to_hash) ||
        schema_node['additionalProperties'] ||
        schema_node['patternProperties'] ||
        schema_node['default'].respond_to?(:to_hash) ||
        (schema_node['enum'].respond_to?(:to_ary) && schema_node['enum'].all? { |enum| enum.respond_to?(:to_hash) }) ||
        schema_node['oneOf'].respond_to?(:to_ary) &&
          schema_node['oneOf'].all? { |someof_node| self.class.new(someof_node).describes_hash? } ||
        schema_node['allOf'].respond_to?(:to_ary) &&
          schema_node['allOf'].all? { |someof_node| self.class.new(someof_node).describes_hash? } ||
        schema_node['anyOf'].respond_to?(:to_ary) &&
          schema_node['anyOf'].all? { |someof_node| self.class.new(someof_node).describes_hash? }
    end

    def described_hash_property_names
      Set.new.tap do |property_names|
        if schema_node['properties'].respond_to?(:to_hash)
          property_names.merge(schema_node['properties'].keys)
        end
        if schema_node['required'].respond_to?(:to_ary)
          property_names.merge(schema_node['required'].to_ary)
        end
        # we _could_ look at the properties of 'default' and each 'enum' but ... nah.
        # we should look at dependencies (TODO).
        %w(oneOf allOf anyOf).select { |k| schema_node[k].respond_to?(:to_ary) }.each do |schemas_key|
          schema_node[schemas_key].map(&:deref).map do |someof_node|
            property_names.merge(self.class.new(someof_node).described_hash_property_names)
          end
        end
      end
    end

    def fully_validate(object)
      ::JSON::Validator.fully_validate(schema_node.document, object_to_content(object), fragment: schema_node.fragment)
    end
    def validate(object)
      ::JSON::Validator.validate(schema_node.document, object_to_content(object), fragment: schema_node.fragment)
    end
    def validate!(object)
      ::JSON::Validator.validate!(schema_node.document, object_to_content(object), fragment: schema_node.fragment)
    end

    private
    def object_to_content(object)
      object = object.object if object.is_a?(Scorpio::SchemaObjectBase)
      object = object.content if object.is_a?(Scorpio::JSON::Node)
      object
    end
  end
end
