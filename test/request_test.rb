# frozen_string_literal: true
require_relative 'test_helper'

describe("Request") do
  describe("path item parameters") do
    it("uses path item parameters") do
      oad = Scorpio::OpenAPI::Document.from_instance(YAML.safe_load(<<~YAML
        openapi: 3.1.0
        paths:
          '/{a}':
            parameters:
              - name: a
                in: path
              - name: b
                in: header
            get:
              parameters:
                - name: c
                  in: header
        YAML
      ))

      request = oad.operations.first.build_request(a: 'A', b: 'B', c: 'C')
      assert_equal({'a' => 'A'}, request.path_params)
      assert_equal({'b' => 'B', 'c' => 'C'}, request.headers)
    end

    it("is ambiguous") do
      oad = Scorpio::OpenAPI::Document.from_instance(YAML.safe_load(<<~YAML
        openapi: 3.1.0
        paths:
          '/':
            parameters:
              - name: a
                in: header
            get:
              parameters:
                - name: a
                  in: query
        YAML
      ))

      assert_raises(Scorpio::AmbiguousParameter) { oad.operations.first.build_request(a: 'A') }
    end
  end
end
