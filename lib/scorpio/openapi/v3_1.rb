# frozen_string_literal: true

module Scorpio
  module OpenAPI
    module V3_1
      module Document
        include(OpenAPI::Document::V3Methods)
      end


      # namespace
      module Unscoped
      end

      Unscoped::Document = JSI.new_schema_module(
        YAML.safe_load(Scorpio.root.join('documents/spec.openapis.org/oas/3.1/schema.yaml').read),
      )
      # Schema module: describes an OpenAPI document, but not normally instantiated.
      #
      # This document schema has no dynamic scope pointing `$dynamicAnchor: "meta"` to a real
      # meta-schema. Schemas in the document described by this are just `type: [object, boolean]`,
      # have no dialect, and are not usable schemas.
      #
      # - $id: `https://spec.openapis.org/oas/3.1/schema/2022-10-07`
      module Unscoped::Document
      end
    end
  end
end
