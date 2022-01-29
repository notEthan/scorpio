module Scorpio
  module OpenAPI
    # OperationsScope acts as an Enumerable of the Operations for an openapi_document,
    # and offers subscripting by operationId.
    class OperationsScope
      # @param openapi_document [Scorpio::OpenAPI::Document]
      def initialize(openapi_document)
        jsi_initialize_memos
        @openapi_document = openapi_document
        @operations_by_id = Hash.new do |h, operationId|
          op = detect { |operation| operation.operationId == operationId }
          unless op
            raise(::KeyError, "operationId not found: #{operationId.inspect}")
          end
          op
        end
      end
      attr_reader :openapi_document

      # @yield [Scorpio::OpenAPI::Operation]
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

      # @param operationId
      # @return [Scorpio::OpenAPI::Operation] the operation with the given operationId
      # @raise [::KeyError] if the given operationId does not exist
      def [](operationId)
        @operations_by_id[operationId]
      end
    end
  end
end
