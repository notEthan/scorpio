module Scorpio
  module OpenAPI
    module Reference
      # overrides JSI::Base#[] to implicitly dereference this Reference, except when
      # the given token is present in this Reference's instance (this should usually
      # only apply to the token '$ref')
      def [](token, *a, &b)
        if respond_to?(:to_hash) && !key?(token)
          deref do |deref_jsi|
            return deref_jsi[token]
          end
        end
        return super
      end
    end
  end
end
