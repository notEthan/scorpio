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

  describe("querystring") do
    it("sets") do
      oad = Scorpio::OpenAPI::Document.from_instance(YAML.safe_load(<<~YAML
        openapi: 3.2.0
        paths:
          '/':
            get:
              parameters:
                - name: param1
                  in: querystring
        YAML
      ))

      request = oad.operations.first.build_request(param1: 'x')
      assert_equal('x', request.get_param('param1'))
      assert_equal('x', request.querystring)
      assert_equal('/?x', request.path.to_s)
    end

    it("with in: query param") do
      oad = Scorpio::OpenAPI::Document.from_instance(YAML.safe_load(<<~YAML
        openapi: 3.2.0
        paths:
          '/':
            get:
              parameters:
                - name: param1
                  in: querystring
                - name: param2
                  in: query
        YAML
      ))

      # it builds the request and sets querystring and query_params, but errors when constructing Request#path.
      # in future might change Request#query_params= and Request#querystring= to raise instead.
      request = oad.operations.first.build_request(param1: 'x', param2: 'y')
      assert_equal('x', request.get_param('param1'))
      assert_equal('x', request.querystring)
      assert_equal('y', request.get_param('param2'))
      assert_equal({'param2' => 'y'}, request.query_params)
      assert_raises(Scorpio::AmbiguousParameter) { request.path }
    end
  end
end
