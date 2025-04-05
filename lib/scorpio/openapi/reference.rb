# frozen_string_literal: true

module Scorpio
  module OpenAPI
    module Reference
      # Derefable is included on the schema module of any schema that describes a reference or has an
      # in-place applicator that describes a reference. You can call #deref regardless whether an object
      # is of an expected type, or a reference to one, or a reference to a reference to one.
      module Derefable
        # resolves references ({Reference#resolve}) recursively.
        def deref
          return self unless is_a?(Reference) && has_ref?
          resolved = resolve
          return resolved if !resolved.is_a?(Reference)
          resolved.deref
        end
      end

      # overrides JSI::Base#[] to implicitly resolve this Reference, except when
      # the given token is present in this Reference's instance (this should usually
      # only apply to the token '$ref')
      def [](token, **kw)
        if respond_to?(:to_hash) && !key?(token)
          resolve do |resolved|
            return(resolved[token, **kw])
          end
        end
        return super
      end

      # @return [Boolean]
      def has_ref?
        jsi_child_token_present?('$ref')
      end

      # yields or returns the target of this reference
      # @yield [JSI::Base] if a block is given
      # @return [JSI::Base]
      def resolve
        return unless has_ref?

        ref = @memos.fetch(:oa_ref) { @memos[:oa_ref] = JSI::Ref.new(jsi_node_content['$ref'], referrer: self) }

        # TODO type check resolved

        yield ref.resolve if block_given?

        ref.resolve
      end
    end
  end
end
