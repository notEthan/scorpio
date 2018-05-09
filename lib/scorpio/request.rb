module Scorpio
  class Request
    module Configurables
      attr_writer :path_params
      def path_params
        return @path_params if instance_variable_defined?(:@path_params)
        {}.freeze
      end

      attr_writer :server
      def server
        return @server if instance_variable_defined?(:@server)
        nil
      end

      attr_writer :server_variables
      def server_variables
        return @server_variables if instance_variable_defined?(:@server_variables)
        {}.freeze
      end

      attr_writer :base_url
      def base_url
        return @base_url if instance_variable_defined?(:@base_url)
        raise(NotImplementedError)
      end

      attr_writer :faraday_request_middleware
      def faraday_request_middleware
        return @faraday_request_middleware if instance_variable_defined?(:@faraday_request_middleware)
        [].freeze
      end

      attr_writer :faraday_response_middleware
      def faraday_response_middleware
        return @faraday_response_middleware if instance_variable_defined?(:@faraday_response_middleware)
        [].freeze
      end

      attr_writer :faraday_adapter
      def faraday_adapter
        return @faraday_adapter if instance_variable_defined?(:@faraday_adapter)
        [Faraday.default_adapter].freeze
      end
    end
    include Configurables

    def initialize(operation, &b)
      @operation = operation
      if block_given?
        yield self
      end
    end

    attr_reader :operation

    def http_method
      operation.http_method.downcase.to_sym
    end

    def path_template
      Addressable::Template.new(operation.path)
    end

    def path
      missing_variables = path_template.variables - path_params.keys
      if missing_variables.any?
        raise(ArgumentError, "path #{operation.path} for operation #{operation.operationId} requires path_params " +
          "which were missing: #{missing_variables.inspect}")
      end
      empty_variables = path_template.variables.select { |v| path_params[v].to_s.empty? }
      if empty_variables.any?
        raise(ArgumentError, "path #{operation.path} for operation #{operation.operationId} requires path_params " +
          "which were empty: #{empty_variables.inspect}")
      end

      path_template.expand(path_params)
    end

    def url
      unless base_url
        raise(ArgumentError, "no base_url has been specified for request")
      end
      # we do not use Addressable::URI#join as the paths should just be concatenated, not resolved.
      # we use File.join just to deal with consecutive slashes.
      url = File.join(base_url, path)
      url = Addressable::URI.parse(url)
    end
  end
end
