# frozen_string_literal: true

module Scorpio
  module OpenAPI::SchemaElements
    instance_types = {
      'boolean' => proc { instance == true || instance == false },
      'object' => proc { instance.respond_to?(:to_hash) },
      'array' => proc { instance.respond_to?(:to_ary) },
      'string' => proc { instance.respond_to?(:to_str) },
      'number' => proc { instance.is_a?(Numeric) },
      'integer' => proc { internal_integer?(instance) },
    }.freeze

    TYPE_NULLABLE = JSI::Schema::Element.new(keywords: ['type', 'nullable']) do |element|
      element.add_action(:validate) do
        next if !keyword?('type')
        if instance.nil?
          validate(
            schema_content['nullable'] == true,
            'validation.keyword.type.not_nullable',
            "instance is null without `nullable` = true",
            keyword: 'nullable',
          )
        else
          if !instance_types.key?(schema_content['type'])
            next # schema error; skip validation
          end
          validate(
            instance_exec(&instance_types[schema_content['type']]),
            'validation.keyword.type.not_match',
            "instance type does not match `type` value",
            keyword: 'type',
          )
        end
      end
    end
  end
end
