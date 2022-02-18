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

    # media types for which Scorpio has implemented parsing {Response#body_object} from {Response#body}
    SUPPORTED_MEDIA_TYPES = %w(
      application/json
    ).map(&:freeze).freeze

    # the body (String) is parsed according to the response media type, if
    # supported (see {Response::SUPPORTED_MEDIA_TYPES}), and instantiated
    # as a JSI instance of {#response_schema} if that is defined.
    #
    # @param mutable [Boolean] instantiate the response body object as mutable?
    def body_object(mutable: false)
      if json?
        if body.empty?
          # an empty body isn't valid json, of course, but we'll just return nil for it.
          body_object = nil
        else
          begin
            body_object = JSON.parse(body, freeze: !mutable)
          #rescue ::JSON::ParserError
            # TODO
          end
        end

      # NOTE: the supported media types above should correspond to Response::SUPPORTED_MEDIA_TYPES

      elsif content_type && content_type.type_text? && content_type.subtype?('plain')
        body_object = body
      else
        # we will return the body if we do not have a supported parsing. for now.
        body_object = body
      end

      if response_schema && (body_object.respond_to?(:to_hash) || body_object.respond_to?(:to_ary))
        body_object = response_schema.new_jsi(body_object, mutable: mutable)
      end

      body_object
    end
  end
end
