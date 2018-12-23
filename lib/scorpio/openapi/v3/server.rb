module Scorpio
  module OpenAPI
    module V3
      raise(Bug) unless const_defined?(:Server)
      class Server
        def expanded_url(given_server_variables)
          if variables
            server_variables = (given_server_variables.keys | variables.keys).map do |key|
              server_variable = variables[key]
              if server_variable && server_variable.enum
                unless server_variable.enum.include?(given_server_variables[key])
                  warn # TODO BLAME
                end
              end
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
          template.expand(server_variables)
        end
      end
    end
  end
end
