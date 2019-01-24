module Scorpio
  class Response
    def response_schema
      ur.scorpio_request.operation.response_schema(status: status, media_type: media_type)
    end
  end
end
