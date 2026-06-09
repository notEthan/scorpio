# frozen_string_literal: true
require_relative 'test_helper'

describe("OpenAPI::Document") do
  describe("v3.2 base URI, $self") do
    it("identifies") do
      oad_self_abs = Scorpio::OpenAPI::Document.from_instance(YAML.safe_load(<<~YAML
        openapi: 3.2.0
        $self: "tag:6a/self"
        components:
          schemas:
            z:
              $id: z
        YAML
      ), register: true)
      assert_equal(oad_self_abs, JSI.registry.find('tag:6a/self'))
      assert_equal(oad_self_abs.components.schemas['z'], JSI.registry.find('tag:6a/z'))

      oad_self_rel_base = Scorpio::OpenAPI::Document.from_instance(YAML.safe_load(<<~YAML
        openapi: 3.2.0
        $self: "base/self"
        components:
          schemas:
            z:
              $id: z
        YAML
      ), register: true, base_uri: 'tag:6b/base')
      assert_equal(oad_self_rel_base, JSI.registry.find('tag:6b/base/self'))
      assert_equal(oad_self_rel_base.components.schemas['z'], JSI.registry.find('tag:6b/base/z'))

      oad_self_rel_root = Scorpio::OpenAPI::Document.from_instance(YAML.safe_load(<<~YAML
        openapi: 3.2.0
        $self: "root/self"
        components:
          schemas:
            z:
              $id: z
        YAML
      ), register: true, root_uri: 'tag:6c/root')
      assert_equal(oad_self_rel_root, JSI.registry.find('tag:6c/root'))
      assert_equal(oad_self_rel_root, JSI.registry.find('tag:6c/root/self'))
      assert_equal(oad_self_rel_root.components.schemas['z'], JSI.registry.find('tag:6c/root/z'))
    end

    it("agrees with OAS v3.2 Appendix F.1 Base URI Within Content") do
      # https://spec.openapis.org/oas/v3.2.0.html#base-uri-within-content
      oad_f1 = Scorpio::OpenAPI::Document.from_instance(YAML.safe_load(<<~YAML
        openapi: 3.2.0
        $self: https://example.com/api/openapi
        info:
          title: Example API
          version: 1.0
        paths:
          /foo:
            get:
              requestBody:
                $ref: "shared/foo#/components/requestBodies/Foo"
        YAML
      ), register: true, root_uri: 'file://home/someone/src/api/openapi.yaml')
      oad_f1foo = Scorpio::OpenAPI::Document.from_instance(YAML.safe_load(<<~YAML
        openapi: 3.2.0
        $self: https://example.com/api/shared/foo
        info:
          title: Shared components for all APIs
          version: 1.0
        components:
          requestBodies:
            Foo:
              content:
                application/json:
                  schema:
                    $ref: ../schemas/foo
          schemas:
            Foo:
              $id: https://example.com/api/schemas/foo
              properties:
                bar:
                  $ref: bar
            Bar:
              $id: https://example.com/api/schemas/bar
              type: string
        YAML
      ), register: true, root_uri: 'https://git.example.com/shared/blob/main/shared/foo.yaml')
      assert_equal(oad_f1foo.components.requestBodies['Foo'], oad_f1.paths['/foo'].get.requestBody.resolve)
      assert_equal(oad_f1foo.components.schemas['Foo'], oad_f1foo.components.requestBodies['Foo'].content['application/json'].schema.schema_ref.resolve)
      assert_equal(oad_f1foo.components.schemas['Bar'], oad_f1foo.components.schemas['Foo'].properties['bar'].schema_ref.resolve)
    end

    it("agrees with OAS v3.2 Appendix F.2 Base URI From Encapsulating Entity") do
      # https://spec.openapis.org/oas/v3.2.0.html#base-uri-from-encapsulating-entity
      oad_f2 = Scorpio::OpenAPI::Document.from_instance(YAML.safe_load(<<~YAML
        openapi: 3.2.0
        info:
          title: Example API
          version: 1.0
          externalDocs:
            url: docs.html
        components:
          requestBodies:
            Foo:
              content:
                application/json:
                  schema:
                    $ref: "#/components/schemas/Foo"
          schemas:
            Foo:
              properties:
                bar:
                  $ref: schemas/bar
        YAML
      ), register: true, root_uri: 'https://example.com/api/openapi.yaml')
      schema_f2bar = JSI::JSONSchemaDraft202012.new_schema({"type": "string"}, root_uri: 'https://example.com/api/schemas/bar')
      assert_equal(oad_f2.components.schemas['Foo'], oad_f2.components.requestBodies['Foo'].content['application/json'].schema.schema_ref.resolve)
      assert_equal(schema_f2bar, oad_f2.components.schemas['Foo'].properties['bar'].schema_ref.resolve)
    end

    # F.3 seems redundant with F.2. F.4 is not relevant.

    it("agrees with OAS v3.2 Appendix F.5 Resolving Relative $self and $id") do
      # https://spec.openapis.org/oas/v3.2.0.html#resolving-relative-self-and-id
      oad_f5 = Scorpio::OpenAPI::Document.from_instance(YAML.safe_load(<<~YAML
        openapi: 3.2.0
        $self: /api/openapi
        info:
          title: Example API
          version: 1.0
        paths:
          /foo:
            get:
              requestBody:
                $ref: "shared/foo#/components/requestBodies/Foo"
        YAML
      ), register: true, root_uri: 'https://staging.example.com/api/openapi')
      oad_f5foo = Scorpio::OpenAPI::Document.from_instance(YAML.safe_load(<<~YAML
        openapi: 3.2.0
        $self: /api/shared/foo
        info:
          title: Shared components for all APIs
          version: 1.0
        components:
          requestBodies:
            Foo:
              content:
                application/json:
                  schema:
                    $ref: ../schemas/foo
          schemas:
            Foo:
              $id: /api/schemas/foo
              properties:
                bar:
                  $ref: bar
            Bar:
              $id: /api/schemas/bar
              type: string
        YAML
      ), register: true, root_uri: 'https://staging.example.com/api/shared/foo')
      assert_equal(oad_f5, JSI.registry.find('https://staging.example.com/api/openapi'))
      assert_equal(oad_f5foo, JSI.registry.find('https://staging.example.com/api/shared/foo'))
      assert_equal(oad_f5foo.components.schemas['Foo'], JSI.registry.find('https://staging.example.com/api/schemas/foo'))
      assert_equal(oad_f5foo.components.schemas['Bar'], JSI.registry.find('https://staging.example.com/api/schemas/bar'))
      assert_equal(oad_f5foo.components.requestBodies['Foo'], oad_f5.paths['/foo'].get.requestBody.resolve)
      assert_equal(oad_f5foo.components.schemas['Foo'], oad_f5foo.components.requestBodies['Foo'].content['application/json'].schema.schema_ref.resolve)
      assert_equal(oad_f5foo.components.schemas['Bar'], oad_f5foo.components.schemas['Foo'].properties['bar'].schema_ref.resolve)
    end
  end
end
