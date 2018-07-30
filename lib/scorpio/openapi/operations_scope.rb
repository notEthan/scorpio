module Scorpio
  module OpenAPI
    class OperationsScope
      include JSI::Memoize

      def initialize(openapi_document)
        @openapi_document = openapi_document
      end
      attr_reader :openapi_document

      def each
        openapi_document.paths.each do |path, path_item|
          path_item.each do |http_method, operation|
            if operation.is_a?(Scorpio::OpenAPI::Operation)
              yield operation
            end
          end
        end
      end
      include Enumerable

      def [](operationId_)
        memoize(:[], operationId_) do |operationId|
          detect { |operation| operation.operationId == operationId }
        end
      end
    end
  end
end
