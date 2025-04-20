# frozen_string_literal: true

module Scorpio
  module OpenAPI
      # An object representing a Server.
      module Server
        # expands this server's #url template using the given_server_variables. any variables
        # that are in the url but not in the given server variables are filled in
        # using the default value for the variable.
        #
        # @param given_server_variables [Hash<String, String>]
        # @return [Addressable::URI] the expanded url
        def expanded_url(given_server_variables)
          if variables
            server_variables = (given_server_variables.keys | variables.keys).map do |key|
              server_variable = variables[key]
              if given_server_variables.key?(key)
                {key => given_server_variables[key]}
              elsif server_variable.key?('default')
                {key => server_variable.default}
              else
                {}
              end
            end.inject({}, &:update)
          else
            server_variables = given_server_variables
          end
          template = Addressable::Template.new(url)
          template.expand(server_variables).freeze
        end
      end
  end
end
