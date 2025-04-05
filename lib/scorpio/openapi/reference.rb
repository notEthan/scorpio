# frozen_string_literal: true

module Scorpio
  module OpenAPI
    module Reference
      # @private
      module IncludeRecursive
        def included(mod)
          super
          return if mod.is_a?(Class)
          mod.send(:extend, IncludeRecursive)
        end

        # yield all of the schema's in-place applicator schemas, recursively, following $ref.
        # TODO find a better home for this code (it is not particular to OpenAPI::Reference)
        def schema_all_inplace_applicator_schemas(schema, &block)
          yield schema
          if schema.keyword?('$ref')
            schema_all_inplace_applicator_schemas(schema.schema_ref.resolve, &block)
          end
          ia_elements = schema.dialect.elements.select { |element| element.invokes?(:inplace_applicate) }
          cxt = JSI::Schema::Cxt::Block.new(
            schema: schema,
            abort: false,
            block: proc { |ptr| schema_all_inplace_applicator_schemas(schema.subschema(ptr), &block) },
          )
          ia_elements.each do |element|
            # getting subschemas yielded from action :subschema on elements that invoke :inplace_applicate
            # is a kind of hacky way to get _all_ inplace applicators.
            # getting applicator schemas normally comes from invoking :inplace_applicate, but that
            # requires an instance and yields just the applicators that apply to that instance, not all.
            #
            # this does not work when the schemas an element yields from :subschema do not match its in-place
            # applicator schemas. the only element that does that is for $ref which is handled above.
            element.actions[:subschema].each do |action|
              cxt.instance_exec(&action)
            end
          end
        end
      end

      extend(IncludeRecursive)

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
