module Scorpio
  module OpenAPI
    module Tag
      # operations in the openapi document which have a tag with this tag's name
      # @return [Enumerable<Scorpio::OpenAPI::Operation>]
      def operations
        return(@operations) if instance_variable_defined?(:@operations)
        @operations = OperationsScope.new(each_operation)
      end

      def each_operation(&block)
        unless jsi_root_node.is_a?(OpenAPI::Document)
          raise("Tag#each_operation cannot be used on a Tag that is not inside an OpenAPI document")
        end

        return(to_enum(__method__)) unless block

        jsi_root_node.each_operation do |op|
          yield(op) if op.tags.respond_to?(:to_ary) && op.tags.include?(name)
        end
      end
    end
  end
end
