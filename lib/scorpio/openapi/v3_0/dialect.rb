# frozen_string_literal: true

module Scorpio
  module OpenAPI::V3_0
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

        JSI::Schema::Elements::MAX_ITEMS[],

        JSI::Schema::Elements::MIN_ITEMS[],

        JSI::Schema::Elements::UNIQUE_ITEMS[],

        JSI::Schema::Elements::MAX_PROPERTIES[],

        JSI::Schema::Elements::MIN_PROPERTIES[],

        JSI::Schema::Elements::REQUIRED[],

        JSI::Schema::Elements::ENUM[],

        # TODO `nullable`
        JSI::Schema::Elements::TYPE[],

        JSI::Schema::Elements::ALL_OF[],
        JSI::Schema::Elements::ONE_OF[],
        JSI::Schema::Elements::ANY_OF[],

        JSI::Schema::Elements::NOT[],

        # TODO this should not include additionalItems
        JSI::Schema::Elements::ITEMS[],

        # TODO this should not include patternProperties
        JSI::Schema::Elements::PROPERTIES[],

        JSI::Schema::Elements::INFO_STRING[keyword: 'title'],
        JSI::Schema::Elements::INFO_STRING[keyword: 'description'],

        JSI::Schema::Elements::INFO_BOOL[keyword: 'readOnly'],
        JSI::Schema::Elements::INFO_BOOL[keyword: 'writeOnly'],
        JSI::Schema::Elements::INFO_BOOL[keyword: 'deprecated'],

        JSI::Schema::Elements::DEFAULT[],

        JSI::Schema::Elements::FORMAT[],

        JSI::Schema::Element.new(keyword: 'externalDocs') { }, # no actions
        JSI::Schema::Element.new(keyword: 'example') { }, # no actions

        # TODO `discriminator`
        # TODO `xml`
      ],
    )

    # https://spec.openapis.org/oas/v3.0.4.html#schema-object
    DIALECT = JSI::Schema::Dialect.new(
      vocabularies: [VOCABULARY],
      integer_disallows_0_fraction: true,
    )
  end
end
