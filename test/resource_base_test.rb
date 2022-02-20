# frozen_string_literal: true

require_relative('test_helper')

describe(Scorpio::ResourceBase) do
  let(:app) { proc { [200, {'Content-Type' => 'application/json'}, ['{"☺": true}']] } }

  let(:openapi_class) do
    openapi_class = Class.new(Scorpio::ResourceBase)
    openapi_class.openapi_document = openapi_document_content
    openapi_class.faraday_adapter = [:rack, app]
    openapi_class.base_url = 'http://scorpio'
    openapi_class
  end

  let(:components) do
    openapi_class.openapi_document.components
  end

  def resource(represented_schemas: nil, tag_name: nil)
    resource = Class.new(openapi_class)
    resource.represented_schemas = represented_schemas if represented_schemas
    resource.tag_name = tag_name if tag_name
    resource
  end

  describe("mapping response schemas to resources") do
    let(:openapi_document_content) do
      YAML.load(<<~YAML
        openapi: "3.0.0"
        paths:
          /:
            get:
              operationId: go
              responses:
                "200":
                  description: "200"
                  content:
                    application/json:
                      schema:
                        allOf:
                        - "$ref": "#/components/schemas/a"
                        - "$ref": "#/components/schemas/b"
        components:
          schemas:
            a:
              title: A
            b:
              title: B
        YAML
      )
    end

    it("makes the response an instance of a mapped resource") do
      a_resource = resource(represented_schemas: [components.schemas['a']])
      a = a_resource.go
      assert_kind_of(a_resource, a)
      resp_sch = openapi_class.openapi_document['paths']['/']['get']['responses']['200']['content']['application/json']['schema']
      assert_equal(resp_sch.new_jsi({"☺" => true}), a.attributes)
    end

    it("trips on ambiguous resource mapping") do
      a_resource = resource(represented_schemas: [components.schemas['a']])
      resource(represented_schemas: [components.schemas['b']])

      # since the response from a_resource.go is allOf schemas a and b,
      # and both schemas have a ResourceBase subclass representing them,
      # scorpio finds both resource classes, cannot instantiate the response as both classes, and raises.
      err = assert_raises(Scorpio::OpenAPI::Error) { a_resource.go }
      assert_match(/multiple models indicated by response JSI/, err.message)
    end
  end

  describe("resource class operation methods") do
    describe("when the operation has the resource's tag") do
      let(:openapi_document_content) do
        YAML.load(<<~YAML
          openapi: "3.0"
          paths:
            /tagged_a:
              get:
                operationId: a
                tags:
                - a
            /tagged_b:
              get:
                operationId: b
                tags:
                - b
          YAML
        )
      end

      it("defines class method") do
        assert_equal({"☺" => true}, resource(tag_name: 'a').a)
        refute(resource(tag_name: 'a').respond_to?(:b))
      end
    end

    describe("when the operation request schema is the resource represented schema") do
      let(:openapi_document_content) do
        YAML.load(<<~YAML
          openapi: "3.0"
          paths:
            /:
              post:
                operationId: go
                requestBody:
                  $ref: "#/components/requestBodies/a"
          components:
            requestBodies:
              a:
                content:
                  application/json:
                    schema:
                      title: a
          YAML
        )
      end

      it("defines class method") do
        res = resource(represented_schemas: [components.requestBodies['a'].content['application/json'].schema])
        assert_equal({"☺" => true}, res.go)
      end
    end

    describe("when the operation response schema is resource represented schema") do
      let(:openapi_document_content) do
        YAML.load(<<~YAML
          openapi: "3.0"
          paths:
            /:
              get:
                operationId: go
                responses:
                  default:
                    description: default
                    content:
                      application/json:
                        schema:
                          $ref: "#/components/schemas/a"
          components:
            schemas:
              a:
                title: a
          YAML
        )
      end

      it("defines class method") do
        res = resource(represented_schemas: [components.schemas['a']])
        response_schema = openapi_class.openapi_document['paths']['/']['get']['responses']['default']['content']['application/json']['schema']
        assert_equal(res.new(response_schema.new_jsi({"☺" => true})), res.go)
      end
    end
  end
end
