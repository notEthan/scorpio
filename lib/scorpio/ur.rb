module Scorpio
  class Ur < ::Ur
    attr_accessor :scorpio_request

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
