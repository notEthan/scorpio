# frozen_string_literal: true

module Scorpio
  Response = Scorpio::Ur.properties['response']

  # Scorpio::Response is a JSI schema module describing the same instances as ::Ur::Response.
  # It relies on methods of that module.
  module Response
    # the schema for this response according to its OpenAPI doc
    # @return [::JSI::Schema]
    def response_schema
      ur.scorpio_request.operation.response_schema(status: status, media_type: media_type)
    end

    # the body (String) is parsed according to the response media type, if supported (only JSON is
    # currently supported), and instantiated as a JSI instance of {#response_schema} if that is defined.
    def body_object
      if json?
        if body.empty?
          # an empty body isn't valid json, of course, but we'll just return nil for it.
          body_object = nil
        else
          begin
            body_object = ::JSON.parse(body)
          #rescue ::JSON::ParserError
            # TODO
          end
        end

        if response_schema && (body_object.respond_to?(:to_hash) || body_object.respond_to?(:to_ary))
          body_object = response_schema.new_jsi(body_object, mutable: true)
        end

        body_object
      elsif content_type && content_type.type_text? && content_type.subtype?('plain')
        body
      else
        # we will return the body if we do not have a supported parsing. for now.
        body
      end
    end
  end
end
