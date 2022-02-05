# frozen_string_literal: true

module Scorpio
  # Scorpio::Ur is a JSI Schema module with which scorpio extends the ::Ur (toplevel)
  # schema module from the Ur gem
  Ur = JSI.new_schema_module({
    '$schema' => 'http://json-schema.org/draft-07/schema#',
    '$id' => 'https://schemas.jsi.unth.net/ur',
    'properties' => {
      'request' => {},
      'response' => {},
    }
  })

  -> { Scorpio::Response }.() # invoke autoload

  module Ur
    attr_accessor :scorpio_request

    # raises a subclass of Scorpio::HTTPError if the response has an error status.
    # raises nothing if the status is 2xx.
    # raises ClientError or one of its response-specific subclasses if the status is 4xx.
    # raises ServerError or one of its response-specific subclasses if the status is 5xx.
    # raises a generic HTTPError otherwise.
    #
    # @raise [Scorpio::HTTPError]
    # @return [void]
    def raise_on_http_error
      error_class = Scorpio.error_classes_by_status[response.status]
      error_class ||= if (400..499).include?(response.status)
        ClientError
      elsif (500..599).include?(response.status)
        ServerError
      elsif !response.success?
        HTTPError
      end
      if error_class
        message = "Error calling operation #{scorpio_request.operation.human_id}:\n" + response.body
        raise(error_class.new(message).tap do |e|
          e.ur = self
          e.response_object = response.body_object
        end)
      end
      nil
    end
  end
end
