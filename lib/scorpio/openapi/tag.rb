module Scorpio
  module OpenAPI
    module Tag
      # operations in the openapi document which have a tag with this tag's name
      # @return [Enumerable<Scorpio::OpenAPI::Operation>]
      def operations
        unless jsi_root_node.is_a?(OpenAPI::Document)
          raise("Tag#operations cannot be used on a Tag that is not inside an OpenAPI document")
        end

        jsi_root_node.operations.select { |op| op.tags.respond_to?(:to_ary) && op.tags.include?(name) }
      end
    end
  end
end
