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

      # each operation tagged with this tag, a child tag of this, or any further descendent tag.
      # @yield [OpenAPI::Operation]
      def each_descendent_tag_operation(&block)
        return(to_enum(__method__)) unless block
        each_operation(&block)
        child_tags.each { |tag| tag.each_descendent_operation(&block) }
        nil
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

      # @return [Enumerable<OpenAPI::Tag>]
      def with_kind(kind)
        select { |tag| tag['kind'] == kind }
      end
    end
  end
end
