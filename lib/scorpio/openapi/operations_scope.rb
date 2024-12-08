# frozen_string_literal: true

module Scorpio
  module OpenAPI
    # OperationsScope is an Enumerable for a collection of Operations,
    # and offers subscripting by operationId.
    class OperationsScope
      # @param enum [Enumerable]
      def initialize(enum)
        @enum = enum
        @operations_by_id = Hash.new do |h, operationId|
          op = enum.detect { |operation| operation.operationId == operationId }
          unless op
            raise(::KeyError, "operationId not found: #{operationId.inspect}")
          end
          h[operationId] = op
        end
      end
      attr_reader :openapi_document

      # @yield [Scorpio::OpenAPI::Operation]
      def each(&block)
        @enum.each(&block)
      end

      include Enumerable

      # finds an operation with the given `operationId`
      # @param operationId [String] the operationId of the operation to find
      # @return [Scorpio::OpenAPI::Operation]
      # @raise [::KeyError] if the given operationId does not exist
      def [](operationId)
        @operations_by_id[operationId]
      end

      # @return [OperationsScope]
      def select(&block)
        OperationsScope.new(@enum.select(&block))
      end

      # @return [OperationsScope]
      def reject(&block)
        OperationsScope.new(@enum.reject(&block))
      end

      # Operations with the indicated tag
      # @param tag [String, OpenAPI::Tag]
      # @return [OperationsScope]
      def tagged(tag)
        tag_name = tag.is_a?(OpenAPI::Tag) ? tag.name : tag
        select { |op| op.tagged?(tag_name) }
      end
    end
  end
end
