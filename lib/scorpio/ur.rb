module Scorpio
  class Ur < ::Ur
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
        message = "Error calling operation #{scorpio_request.operation.operationId}:\n" + response.body
        raise(error_class.new(message).tap do |e|
          e.ur = self
          e.response_object = response.body_object
        end)
      end
      nil
    end

    private
    # overrides JSI::Base#class_for_schema to use Scorpio::Response instead of ::Ur::Response.
    # maybe a Scorpio::Ur::Request in the future if I need to extend that ... or Scorpio::Request
    # if I decide to make that subclass ::Ur::Request. not sure if that's a good idea or a terrible
    # idea.
    def class_for_schema(schema)
      jsi_class_for_schema = super
      if jsi_class_for_schema == ::Ur::Response
        Scorpio::Response
      else
        jsi_class_for_schema
      end
    end
  end
end
