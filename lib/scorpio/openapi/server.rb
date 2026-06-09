# frozen_string_literal: true

module Scorpio
  module OpenAPI
      # An object representing a Server.
      module Server
        include(Document::Descendent)

        # expands this server's #url template using the given_server_variables. any variables
        # that are in the url but not in the given server variables are filled in
        # using the default value for the variable.
        #
        # @param given_server_variables [Hash<String, String>]
        # @return [Addressable::URI] the expanded url
        def expanded_url(given_server_variables)
          given_server_variables = JSI::Util.stringify_symbol_keys(given_server_variables)
          if variables
            server_variables = {}
            (given_server_variables.keys | variables.keys).each do |key|
              if given_server_variables.key?(key)
                server_variables[key] = given_server_variables[key]
              elsif variables[key].key?('default')
                server_variables[key] = variables[key].default
              end
            end
          else
            server_variables = given_server_variables
          end
          template = Addressable::Template.new(url)
          expanded_url = template.expand(server_variables).freeze
          if expanded_url.relative?
            raise(Error, -"server URL is relative with no base URL. server: #{inspect}") if !openapi_document.jsi_base_uri
            # note: this uses the OAD jsi_base_uri, not this server object's, because OAS 3.2
            # excludes $self uri as the base for API urls including server url
            # https://spec.openapis.org/oas/v3.2.0.html#relative-references-in-api-urls
            expanded_url = openapi_document.jsi_base_uri.join(expanded_url)
          end
          expanded_url
        end
      end
  end
end
