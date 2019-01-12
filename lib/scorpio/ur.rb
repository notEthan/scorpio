module Scorpio
  class Ur < ::Ur
    attr_accessor :scorpio_request

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
