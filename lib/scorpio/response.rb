module Scorpio
  class Response < ::Ur::Response
    def response_schema
      ur.scorpio_request.operation.response_schema(status: status, media_type: media_type)
    end

    def body_object
      # TODO handle media types like `application/schema-instance+json` or vendor things like github's
      if media_type == 'application/json'
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
          body_object = JSI.class_for_schema(response_schema).new(JSI::JSON::Node.new_doc(body_object))
        end

        body_object
      elsif media_type == 'text/plain'
        body
      else
        # we will return the body if we do not have a supported parsing. for now.
        body
      end
    end
  end
end
