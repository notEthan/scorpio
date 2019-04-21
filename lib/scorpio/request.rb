module Scorpio
  class Request
    SUPPORTED_REQUEST_MEDIA_TYPES = ['application/json', 'application/x-www-form-urlencoded']
    def self.best_media_type(media_types)
      if media_types.size == 1
        media_types.first
      else
        SUPPORTED_REQUEST_MEDIA_TYPES.detect { |mt| media_types.include?(mt) }
      end
    end

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

          # NOTE: the supported media types above should correspond to Request::SUPPORTED_REQUEST_MEDIA_TYPES

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

      attr_writer :faraday_builder
      def faraday_builder
        return @faraday_builder if instance_variable_defined?(:@faraday_builder)
        operation.faraday_builder
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

    # @param operation [Scorpio::OpenAPI::Operation]
    # @param configuration [#to_hash] a hash keyed with configurable attributes for
    #   the request - instance methods of Scorpio::Request::Configurables, whose values
    #   will be assigned for those attributes.
    def initialize(operation, **configuration, &b)
      @operation = operation

      configuration = JSI.stringify_symbol_keys(configuration)
      configuration.each do |name, value|
        if Configurables.public_method_defined?("#{name}=")
          Configurables.instance_method("#{name}=").bind(self).call(value)
        else
          raise(ArgumentError, "unrecognized configuration value passed: #{name.inspect}")
        end
      end

      if block_given?
        yield self
      end
    end

    # @return [Scorpio::OpenAPI::Operation]
    attr_reader :operation

    # @return [Scorpio::OpenAPI::Document]
    def openapi_document
      operation.openapi_document
    end

    # @return [Symbol] the http method for this request - :get, :post, etc.
    def http_method
      operation.http_method.downcase.to_sym
    end

    # @return [Addressable::Template] the template for the request's path, to be expanded
    #   with path_params and appended to the request's base_url
    def path_template
      operation.path_template
    end

    # @return [Addressable::URI] an Addressable::URI containing only the path to append to
    #   the base_url for this request
    def path
      path_params = JSI.stringify_symbol_keys(self.path_params)
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

    # @return [Addressable::URI] the full URL for this request
    def url
      unless base_url
        raise(ArgumentError, "no base_url has been specified for request")
      end
      # we do not use Addressable::URI#join as the paths should just be concatenated, not resolved.
      # we use File.join just to deal with consecutive slashes.
      url = File.join(base_url, path)
      url = Addressable::URI.parse(url)
    end

    # @return [::Ur::ContentTypeAttrs] content type attributes for this request's Content-Type
    def content_type_attrs
      Ur::ContentTypeAttrs.new(content_type)
    end

    # @return [String] the value of the request Content-Type header
    def content_type_header
      headers.each do |k, v|
        return v if k =~ /\Acontent[-_]type\z/i
      end
      nil
    end

    # @return [String] Content-Type for this request, taken from request headers if
    #   present, or the request media_type.
    def content_type
      content_type_header || media_type
    end

    # @return [::JSI::Schema]
    def request_schema(media_type: self.media_type)
      operation.request_schema(media_type: media_type)
    end

    # @return [Class subclassing JSI::Base]
    def request_schema_class(media_type: self.media_type)
      JSI.class_for_schema(request_schema(media_type: media_type))
    end

    # builds a Faraday connection with this Request's faraday_builder and faraday_adapter.
    # passes a given proc yield_ur to middleware to yield an Ur for requests made with the connection.
    #
    # @param yield_ur [Proc]
    # @return [::Faraday::Connection]
    def faraday_connection(yield_ur = nil)
      Faraday.new do |faraday_connection|
        faraday_builder.call(faraday_connection)
        if yield_ur
          ::Ur::Faraday # autoload trigger
          faraday_connection.response(:yield_ur, ur_class: Scorpio::Ur, logger: self.logger, &yield_ur)
        end
        faraday_connection.adapter(*faraday_adapter)
      end
    end

    # runs this request and returns the full representation of the request that was run and its response.
    #
    # @return [Scorpio::Ur]
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

    # runs this request. returns the response body object - that is, the response body
    # parsed according to an understood media type, and instantiated with the applicable
    # response schema if one is specified. see Scorpio::Response#body_object for more detail.
    #
    # @raise [Scorpio::HTTPError] if the request returns a 4xx or 5xx status, the appropriate
    #   error is raised - see Scorpio::HTTPErrors
    def run
      ur = run_ur
      ur.raise_on_http_error
      ur.response.body_object
    end
  end
end
