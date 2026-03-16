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
  end
end
