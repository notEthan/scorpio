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

      # @yield [OpenAPI::Operation]
      def each_operation(&block)
        return(to_enum(__method__)) unless block

        openapi_document.each_operation do |op|
          yield(op) if op.tags.respond_to?(:to_ary) && op.tags.include?(name)
        end
      end

      # @return [OpenAPI::Tag, nil]
      def parent_tag
        self['parent'] ? openapi_document.tags.named(self['parent']) : nil
      end

      # @return [Enumerable<OpenAPI::Tag>]
      def child_tags
        openapi_document.tags.select { |t| t['parent'] == name }
      end
    end

    module Tags
      # a tag with the given name
      # @return [OpenAPI::Tag, nil]
      def named(name)
        detect { |tag| tag.name == name }
      end
    end
  end
end
