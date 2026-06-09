# frozen_string_literal: true
require_relative 'test_helper'

describe("OpenAPI dialects") do
  describe("`type` + `nullable` (OAS 3.0)") do
    it("validates") do
      oad = Scorpio::OpenAPI::Document.from_instance(YAML.safe_load(<<~YAML
        openapi: 3.0.0
        info: {title: '', version: ''}
        components:
          schemas:
            a:
              type: string
              nullable: true
            b:
              type: string
              nullable: false
            c:
              type: null
              nullable: true
            d:
              type: null
              nullable: false
            e:
              type: wrong
              nullable: true
            f:
              type: wrong
              nullable: false
            g:
              type: [string]
              nullable: true
            h:
              type: [string]
              nullable: false
        YAML
      ))

      assert(oad.components.schemas['a'].new_jsi('').jsi_valid?)
      assert(oad.components.schemas['a'].new_jsi(nil).jsi_valid?)
      refute(oad.components.schemas['a'].new_jsi({}).jsi_valid?)
      assert(oad.components.schemas['b'].new_jsi('').jsi_valid?)
      refute(oad.components.schemas['b'].new_jsi(nil).jsi_valid?)
      refute(oad.components.schemas['b'].new_jsi({}).jsi_valid?)
      assert(oad.components.schemas['c'].new_jsi('').jsi_valid?)  # type = null not recognized; not validated
      assert(oad.components.schemas['c'].new_jsi(nil).jsi_valid?)
      assert(oad.components.schemas['c'].new_jsi({}).jsi_valid?)  # type = null not recognized; not validated
      assert(oad.components.schemas['d'].new_jsi('').jsi_valid?)  # type = null not recognized; not validated
      refute(oad.components.schemas['d'].new_jsi(nil).jsi_valid?) # type = null not recognized, but nullable still validates
      assert(oad.components.schemas['d'].new_jsi({}).jsi_valid?)  # type = null not recognized; not validated
      assert(oad.components.schemas['e'].new_jsi('').jsi_valid?)  # type = wrong not recognized; not validated
      assert(oad.components.schemas['e'].new_jsi(nil).jsi_valid?)
      assert(oad.components.schemas['e'].new_jsi({}).jsi_valid?)  # type = wrong not recognized; not validated
      assert(oad.components.schemas['f'].new_jsi('').jsi_valid?)  # type = wrong not recognized; not validated
      refute(oad.components.schemas['f'].new_jsi(nil).jsi_valid?) # type = wrong not recognized, but nullable still validates
      assert(oad.components.schemas['f'].new_jsi({}).jsi_valid?)  # type = wrong not recognized; not validated
      assert(oad.components.schemas['g'].new_jsi('').jsi_valid?)  # array type not recognized; not validated
      assert(oad.components.schemas['g'].new_jsi(nil).jsi_valid?)
      assert(oad.components.schemas['g'].new_jsi({}).jsi_valid?)  # array type not recognized; not validated
      assert(oad.components.schemas['h'].new_jsi('').jsi_valid?)  # array type not recognized; not validated
      refute(oad.components.schemas['h'].new_jsi(nil).jsi_valid?) # array type not recognized, but nullable still validates
      assert(oad.components.schemas['h'].new_jsi({}).jsi_valid?)  # array type not recognized; not validated
    end
  end
end
