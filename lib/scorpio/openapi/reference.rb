# frozen_string_literal: true

module Scorpio
  module OpenAPI
    module Reference
      # overrides JSI::Base#[] to implicitly dereference this Reference, except when
      # the given token is present in this Reference's instance (this should usually
      # only apply to the token '$ref')
      def [](token, **kw)
        if respond_to?(:to_hash) && !key?(token)
          deref do |deref_jsi|
            return(deref_jsi[token, **kw])
          end
        end
        return super
      end

      # yields or returns the target of this reference
      # @yield [JSI::Base] if a block is given
      # @return [JSI::Base]
      def deref
        return unless respond_to?(:to_hash) && key?('$ref') && jsi_node_content['$ref'].respond_to?(:to_str)

        ref = @memos.fetch(:oa_ref) { @memos[:oa_ref] = JSI::Ref.new(jsi_node_content['$ref'], referrer: self) }

        # TODO type check resolved

        yield ref.resolve if block_given?

        ref.resolve
      end
    end
  end
end
