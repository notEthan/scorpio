# frozen_string_literal: true

module Scorpio
  module OpenAPI::V2
    VOCABULARY = JSI::Schema::Vocabulary.new(
      elements: [
        JSI::Schema::Elements::SELF[],

        JSI::Schema::Elements::REF[exclusive: true],

        JSI::Schema::Elements::MULTIPLE_OF[],

        JSI::Schema::Elements::MAXIMUM_BOOLEAN_EXCLUSIVE[],

        JSI::Schema::Elements::MINIMUM_BOOLEAN_EXCLUSIVE[],

        JSI::Schema::Elements::MAX_LENGTH[],

        JSI::Schema::Elements::MIN_LENGTH[],

        JSI::Schema::Elements::PATTERN[],

        # TODO this should not include additionalItems
        JSI::Schema::Elements::ITEMS[],

        JSI::Schema::Elements::MAX_ITEMS[],

        JSI::Schema::Elements::MIN_ITEMS[],

        JSI::Schema::Elements::UNIQUE_ITEMS[],

        JSI::Schema::Elements::MAX_PROPERTIES[],

        JSI::Schema::Elements::MIN_PROPERTIES[],

        JSI::Schema::Elements::REQUIRED[],

        # TODO this should not include patternProperties
        JSI::Schema::Elements::PROPERTIES[],

        JSI::Schema::Elements::ENUM[],

        JSI::Schema::Elements::TYPE[],

        JSI::Schema::Elements::ALL_OF[],

        JSI::Schema::Elements::INFO_STRING[keyword: 'title'],
        JSI::Schema::Elements::INFO_STRING[keyword: 'description'],

        JSI::Schema::Elements::INFO_BOOL[keyword: 'readOnly'],

        JSI::Schema::Elements::DEFAULT[],

        JSI::Schema::Elements::FORMAT[],

        JSI::Schema::Element.new(keyword: 'example') { }, # no actions
      ],
    )

    # https://spec.openapis.org/oas/v2.0.html#schema-object
    DIALECT = JSI::Schema::Dialect.new(
      vocabularies: [VOCABULARY],
      integer_disallows_0_fraction: true,
    )
  end
end
