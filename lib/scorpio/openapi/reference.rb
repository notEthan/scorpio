module Scorpio
  module OpenAPI
    module Reference
      # overrides JSI::Base#[] to implicitly dereference this Reference, except when
      # the given token is present in this Reference's instance (this should usually
      # only apply to the token '$ref')
      #
      # see JSI::Base#initialize documentation at https://www.rubydoc.info/gems/jsi/JSI/Base
      def [](token, *a, &b)
        if respond_to?(:to_hash) && !key?(token)
          deref do |deref_jsi|
            return deref_jsi[token]
          end
        end
        return super
      end

      def deref
        return unless respond_to?(:to_hash) && self['$ref'].respond_to?(:to_str)

        ref_uri = Addressable::URI.parse(self['$ref'])
        ref_uri_nofrag = ref_uri.merge(fragment: nil)

        if !ref_uri_nofrag.empty? || ref_uri.fragment.nil?
          raise(NotImplementedError,
            "Scorpio currently only supports fragment URIs as OpenAPI references. cannot find reference by uri: #{self['$ref']}"
          )
        end

        ptr = JSI::Ptr.from_fragment(ref_uri.fragment)
        deref_jsi = ptr.evaluate(jsi_root_node)

        # TODO type check deref_jsi

        yield deref_jsi

        nil
      end
    end
  end
end
