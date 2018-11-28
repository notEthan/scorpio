module Scorpio
  class Request
    module Configurables
      attr_writer :path_params
      def path_params
        return @path_params if instance_variable_defined?(:@path_params)
        {}.freeze
      end

      attr_writer :query_params
      def query_params
        return @query_params if instance_variable_defined?(:@query_params)
        nil
      end

      attr_writer :scheme
      def scheme
        return @scheme if instance_variable_defined?(:@scheme)
        operation.scheme
      end

      attr_writer :server
      def server
        return @server if instance_variable_defined?(:@server)
        operation.server
      end

      attr_writer :server_variables
      def server_variables
        return @server_variables if instance_variable_defined?(:@server_variables)
        operation.server_variables
      end

      attr_writer :base_url
      def base_url
        return @base_url if instance_variable_defined?(:@base_url)
        operation.base_url(scheme: scheme, server: server, server_variables: server_variables)
      end

      attr_writer :body
      def body
        return @body if instance_variable_defined?(:@body)
        if instance_variable_defined?(:@body_object)
          # TODO handle media types like `application/schema-instance+json`
          if media_type == 'application/json'
            JSON.pretty_generate(JSI::Typelike.as_json(body_object))
          elsif media_type == "application/x-www-form-urlencoded"
            URI.encode_www_form(body_object)
          else
            if body_object.respond_to?(:to_str)
              body_object
            else
              raise(NotImplementedError)
            end
          end
        else
          nil
        end
      end

      attr_accessor :body_object

      attr_writer :headers
      def headers
        return @headers if instance_variable_defined?(:@headers)
        operation.request_headers
      end

      attr_writer :media_type
      def media_type
        return @media_type if instance_variable_defined?(:@media_type)
        content_type_header ? content_type_attrs.media_type : operation.request_media_type
      end

      attr_writer :user_agent
      def user_agent
        return @user_agent if instance_variable_defined?(:@user_agent)
        operation.user_agent
      end

      attr_writer :faraday_request_middleware
      def faraday_request_middleware
        return @faraday_request_middleware if instance_variable_defined?(:@faraday_request_middleware)
        operation.faraday_request_middleware
      end

      attr_writer :faraday_response_middleware
      def faraday_response_middleware
        return @faraday_response_middleware if instance_variable_defined?(:@faraday_response_middleware)
        operation.faraday_response_middleware
      end

      attr_writer :faraday_adapter
      def faraday_adapter
        return @faraday_adapter if instance_variable_defined?(:@faraday_adapter)
        operation.faraday_adapter
      end

      attr_writer :logger
      def logger
        return @logger if instance_variable_defined?(:@logger)
        operation.logger
      end
    end
    include Configurables

    def initialize(operation, **configuration, &b)
      configuration.each do |k, v|
        settername = "#{k}="
        if Configurables.public_method_defined?(settername)
          Configurables.instance_method(settername).bind(self).call(v)
        else
          raise(ArgumentError, "unsupported configuration value passed: #{k.inspect} => #{v.inspect}")
        end
      end

      @operation = operation
      if block_given?
        yield self
      end
    end

    attr_reader :operation

    def openapi_document
      operation.openapi_document
    end

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

      path_template.expand(path_params).tap do |path|
        if query_params
          path.query_values = query_params
        end
      end
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

    def content_type_attrs
      Ur::ContentTypeAttrs.new(content_type)
    end

    def content_type_header
      headers.each do |k, v|
        return v if k =~ /\Acontent[-_]type\z/i
      end
      nil
    end

    def content_type
      content_type_header || media_type
    end

    def request_schema(media_type: self.media_type)
      operation.request_schema(media_type: media_type)
    end

    def request_schema_class(media_type: self.media_type)
      JSI.class_for_schema(request_schema(media_type: media_type))
    end

    def faraday_connection(yield_ur)
      Faraday.new do |c|
        faraday_request_middleware.each do |m|
          c.request(*m)
        end
        faraday_response_middleware.each do |m|
          c.response(*m)
        end
        ::Ur::Faraday # autoload trigger
        c.response(:yield_ur, ur_class: Scorpio::Ur, logger: self.logger, &yield_ur)
        c.adapter(*faraday_adapter)
      end
    end

    def run_ur
      headers = {}
      if user_agent
        headers['User-Agent'] = user_agent
      end
      if media_type && !content_type_header
        headers['Content-Type'] = media_type
      end
      if self.headers
        headers.update(self.headers)
      end
      ur = nil
      faraday_connection(-> (yur) { ur = yur }).run_request(http_method, url, body, headers)
      ur.scorpio_request = self
      ur
    end

    def run
      run_ur.response.body_object
    end
  end
end
