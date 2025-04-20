# frozen_string_literal: true

require_relative('test_helper')

describe("OpenAPI::Server") do
  describe("#expanded_url") do
    let(:oad_content) do
      YAML.load(<<~YAML
        openapi: 3.0.0
        servers:
        - url: "{basePath}"
          variables:
            basePath:
              enum:
                - v1
              default: v1
        YAML
      )
    end

    it("expands url from document base uri") do
      oad = Scorpio::OpenAPI::Document.from_instance(oad_content, base_uri: 'http://47z')
      assert_equal('http://47z/v1', oad.base_url.to_s)
      # relative server url with no base
      assert_raises(Scorpio::OpenAPI::Error) { Scorpio::OpenAPI::Document.from_instance(oad_content).base_url }
    end
  end
end
