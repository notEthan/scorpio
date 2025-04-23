# frozen_string_literal: true
require_relative 'test_helper'

describe("Scorpio::OpenAPI::Reference") do
  describe("resolution") do
    it("resolves") do
      oad_remoteA_yml = <<~YAML
        openapi: 3.0.0
        info: {title: '', version: ''}
        components:
          parameters:
            paramQremoteA:
              name: paramQ
              in: query
              required: true
              schema:
                type: string
            paramHremoteA:
              name: paramH
              in: header
              required: true
              schema:
                type: string
        YAML
      oad_remoteA = Scorpio::OpenAPI::Document.from_instance(YAML.safe_load(oad_remoteA_yml), root_uri: 'tag:remoteA', register: true)
      oad = Scorpio::OpenAPI::Document.from_instance(YAML.safe_load(<<~YAML
        openapi: 3.0.0
        info: {title: '', version: ''}
        paths:
          '/1/{param1}':
            patch:
              operationId: patch1
              parameters:
                - name: param1
                  in: path
                  required: true
                  schema:
                    type: string
                - $ref: "tag:remoteA#/components/parameters/paramQremoteA"
                - $ref: "#/components/parameters/paramH"
              responses:
                default: {}
        components:
          parameters:
            paramH:
              $ref: "tag:remoteA#/components/parameters/paramHremoteA"
        YAML
      ))

      patch_parameters = oad.paths['/1/{param1}'].patch.parameters
      remoteA_parameters = oad_remoteA.components.parameters

      # not a ref
      assert_equal('param1', patch_parameters[0]['name']) # reader (self)
      assert_equal(patch_parameters[0], patch_parameters[0].deref) # deref (self)

      # remote ref
      assert_equal('paramQ', patch_parameters[1]['name']) # reader (implicit deref)
      assert_equal(remoteA_parameters['paramQremoteA'], patch_parameters[1].resolve) # resolves
      assert_equal(remoteA_parameters['paramQremoteA'], patch_parameters[1].deref) # deref follows ref

      # twice removed
      assert_equal('paramH', patch_parameters[2]['name']) # reader (implicit recursive deref)
      assert_equal(oad.components.parameters['paramH'], patch_parameters[2].resolve) # resolve is immediate
      assert_equal(remoteA_parameters['paramHremoteA'], patch_parameters[2].resolve.resolve) # resolve twice
      assert_equal(remoteA_parameters['paramHremoteA'], patch_parameters[2].deref) # deref recurses
    end
  end
end
