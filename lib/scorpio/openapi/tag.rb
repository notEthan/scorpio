module Scorpio
  module OpenAPI
    module Tag
      include(Document::Descendent)

      # operations in the openapi document which have a tag with this tag's name
      # @return [Enumerable<Scorpio::OpenAPI::Operation>]
      def operations
        return(@operations) if instance_variable_defined?(:@operations)
        @operations = OperationsScope.new(each_operation)
      end

      def each_operation(&block)
        return(to_enum(__method__)) unless block

        openapi_document.each_operation do |op|
          yield(op) if op.tags.respond_to?(:to_ary) && op.tags.include?(name)
        end
      end
    end
  end
end
