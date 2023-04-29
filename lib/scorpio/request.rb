# frozen_string_literal: true

module Scorpio
  # a Request from a {Scorpio::OpenAPI::Operation}.
  # Base class, not directly instantiated; subclassed per operation, defining accessors for operation params.
  # Used by {Scorpio::OpenAPI::Operation#build_request} and related methods.
  class Request
    # media types for which Scorpio has implemented generating / parsing between body
    # and body_object (see {Request#body} and {Response#body_object})
    SUPPORTED_REQUEST_MEDIA_TYPES = %w(
      application/json
      application/x-www-form-urlencoded
    ).map(&:freeze).freeze

    FALLBACK_CONTENT_TYPE = 'application/x-www-form-urlencoded'.freeze

    # see also Faraday::Env::MethodsWithBodies
    METHODS_WITH_BODIES = %w(post put patch options).map(&:freeze).freeze

    def self.best_media_type(media_types)
      if media_types.size == 1
        media_types.first
      else
        SUPPORTED_REQUEST_MEDIA_TYPES.detect { |mt| media_types.include?(mt) }
      end
    end

    # @param http_method [String]
    # @return [Boolean]
    def self.method_with_body?(http_method)
      raise(ArgumentError) unless http_method.is_a?(String)
      METHODS_WITH_BODIES.include?(http_method.downcase)
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
          if content_type && content_type.json?
            JSON.pretty_generate(JSI::Util.as_json(body_object))
          elsif content_type && content_type.form_urlencoded?
            URI.encode_www_form(body_object)

          # NOTE: the supported media types above should correspond to Request::SUPPORTED_REQUEST_MEDIA_TYPES

          else
            if body_object.respond_to?(:to_str)
              body_object
            else
              raise(NotImplementedError, "Scorpio does not know how to generate the request body with content_type = #{content_type.respond_to?(:to_str) ? content_type : content_type.inspect} for operation: #{operation.human_id}. Scorpio supports media types: #{SUPPORTED_REQUEST_MEDIA_TYPES.join(', ')}. body_object was: #{body_object.pretty_inspect.chomp}")
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
        content_type_header ? content_type_header.media_type : operation.request_media_type
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

    @request_class_by_operation = Hash.new do |h, op|
      request_class = Class.new(Request) do
        define_singleton_method(:inspect) { -"#{Request} (for operation: #{op.human_id})" }
        define_method(:operation) { op }
        include(op.request_accessor_module)
      end

      # naming the class helps with debugging and some built-in ruby error messages
      const_name = JSI::Util::Private.const_name_from_parts([
        op.openapi_document && (op.openapi_document.jsi_schema_base_uri || op.openapi_document.title),
        *(op.operationId || [op.http_method, op.path_template_str]),
      ].compact)
      if const_name && !Request.const_defined?(const_name)
        Request.const_set(const_name, request_class)
      end

      h[op] = request_class
    end

    def self.request_class_by_operation(operation)
      @request_class_by_operation[operation]
    end

    # @param configuration [#to_hash] a hash keyed with configurable attributes for
    #   the request - instance methods of Scorpio::Request::Configurables, whose values
    #   will be assigned for those attributes.
    def initialize(configuration = {}, &b)
      configuration = JSI::Util.stringify_symbol_keys(configuration)
      params_set = Set.new # the set of params that have been set
      # do the Configurables first
      configuration.each do |name, value|
        if Configurables.public_method_defined?("#{name}=")
          Configurables.instance_method("#{name}=").bind(self).call(value)
          params_set << name
        end
      end
      # then do other top-level params
      configuration.reject { |name, _| params_set.include?(name) }.each do |name, value|
        param = param_for(name) || raise(ArgumentError, "unrecognized configuration value passed: #{name.inspect}")
        set_param_from(param['in'], param['name'], value)
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

    # the http method for this request
    # @return [String]
    def http_method
      operation.http_method
    end

    # the template for the request's path, to be expanded with {Configurables#path_params} and appended to
    # the request's {Configurables#base_url}
    # @return [Addressable::Template]
    def path_template
      operation.path_template
    end

    # an Addressable::URI containing only the path to append to the {Configurables#base_url} for this request
    # @return [Addressable::URI]
    def path
      path_params = JSI::Util.stringify_symbol_keys(self.path_params)
      missing_variables = path_template.variables - path_params.keys
      if missing_variables.any?
        raise(ArgumentError, "path #{operation.path_template_str} for operation #{operation.human_id} requires path_params " +
          "which were missing: #{missing_variables.inspect}")
      end
      empty_variables = path_template.variables.select { |v| path_params[v].to_s.empty? }
      if empty_variables.any?
        raise(ArgumentError, "path #{operation.path_template_str} for operation #{operation.human_id} requires path_params " +
          "which were empty: #{empty_variables.inspect}")
      end

      path = path_template.expand(path_params)
      if query_params
        path.query_values = query_params
      end
      path.freeze
    end

    # the full URL for this request
    # @return [Addressable::URI]
    def url
      unless base_url
        raise(ArgumentError, "no base_url has been specified for request")
      end
      # we do not use Addressable::URI#join as the paths should just be concatenated, not resolved.
      # we use File.join just to deal with consecutive slashes.
      Addressable::URI.parse(File.join(base_url, path)).freeze
    end

    # the value of the request Content-Type header
    # @return [::Ur::ContentType]
    def content_type_header
      headers.each do |k, v|
        return ::Ur::ContentType.new(v) if k =~ /\Acontent[-_]type\z/i
      end
      nil
    end

    # Content-Type for this request, taken from request headers if present, or the
    # request {Configurables#media_type}.
    # @return [::Ur::ContentType]
    def content_type
      content_type_header || (media_type ? ::Ur::ContentType.new(media_type) : nil)
    end

    # @return [::JSI::Schema]
    def request_schema(media_type: self.media_type)
      operation.request_schema(media_type: media_type)
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
          -> { ::Ur::Faraday }.() # autoload trigger

          faraday_connection.response(:yield_ur, schemas: Set[Scorpio::Ur.schema], logger: self.logger, &yield_ur)
        end
        faraday_connection.adapter(*faraday_adapter)
      end
    end

    # if there is only one parameter with the given name, of any sort, this will set it.
    #
    # @param name [String, Symbol] the 'name' property of one applicable parameter
    # @param value [Object] the applicable parameter will be applied to the request with the given value.
    # @return [Object] echoes the value param
    # @raise (see #param_for!)
    def set_param(name, value)
      param = param_for!(name)
      set_param_from(param['in'], param['name'], value)
      value
    end

    # returns the value of the named parameter on this request
    # @param name [String, Symbol] the 'name' property of one applicable parameter
    # @return [Object]
    # @raise (see #param_for!)
    def get_param(name)
      param = param_for!(name)
      get_param_from(param['in'], param['name'])
    end

    # @param name [String, Symbol] the 'name' property of one applicable parameter
    # @return [#to_hash, nil]
    # @raise [Scorpio::AmbiguousParameter] if more than one parameter has the given name
    def param_for(name)
      name = name.to_s if name.is_a?(Symbol)
      params = operation.inferred_parameters.select { |p| p['name'] == name }
      if params.size == 1
        params.first
      elsif params.size == 0
        nil
      else
        raise(AmbiguousParameter.new(
          "There are multiple parameters for #{name}. matched parameters were: #{params.pretty_inspect.chomp}"
        ).tap { |e| e.name = name })
      end
    end

    # @param name [String, Symbol] the 'name' property of one applicable parameter
    # @return [#to_hash]
    # @raise [Scorpio::ParameterError] if no parameter has the given name
    # @raise (see #param_for)
    def param_for!(name)
      param_for(name) || raise(ParameterError, "There is no parameter named #{name} on operation #{operation.human_id}:\n#{operation.pretty_inspect.chomp}")
    end

    # applies the named value to the appropriate parameter of the request
    # @param param_in [String, Symbol] one of 'path', 'query', 'header', or 'cookie' - where to apply
    #   the named value
    # @param name [String, Symbol] the parameter name to apply the value to
    # @param value [Object] the value
    # @return [Object] echoes the value param
    # @raise [ArgumentError] invalid `param_in` parameter
    # @raise [NotImplementedError] cookies aren't implemented
    def set_param_from(param_in, name, value)
      param_in = param_in.to_s if param_in.is_a?(Symbol)
      name = name.to_s if name.is_a?(Symbol)
      if param_in == 'path'
        self.path_params = self.path_params.merge(name => value)
      elsif param_in == 'query'
        self.query_params = (self.query_params || {}).merge(name => value)
      elsif param_in == 'header'
        self.headers = self.headers.merge(name => value.to_str)
      elsif param_in == 'cookie'
        raise(NotImplementedError, "cookies not implemented: #{name.inspect} => #{value.inspect}")
      else
        raise(ArgumentError, "cannot set param from param_in = #{param_in.inspect} (name: #{name.pretty_inspect.chomp}, value: #{value.pretty_inspect.chomp})")
      end
      value
    end

    # returns the value of the named parameter from the specified `param_in` on this request
    # @param param_in [String, Symbol] one of 'path', 'query', 'header', or 'cookie' - where to retrieve
    #   the named value
    # @param name [String, Symbol] the parameter name
    # @return [Object]
    # @raise [OpenAPI::SemanticError] invalid `param_in` parameter
    # @raise [NotImplementedError] cookies aren't implemented
    def get_param_from(param_in, name)
      if param_in == 'path'
        path_params[name]
      elsif param_in == 'query'
        query_params ? query_params[name] : nil
      elsif param_in == 'header'
        _, value = headers.detect { |headername, _| headername.downcase == name.downcase }
        value
      elsif param_in == 'cookie'
        raise(NotImplementedError, "cookies not implemented: #{name.inspect}")
      else
        raise(OpenAPI::SemanticError, "cannot get param from param_in = #{param_in.inspect} (name: #{name.pretty_inspect.chomp})")
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
      if !content_type_header
        if media_type
          headers['Content-Type'] = media_type
        else
          # I'd rather not have a default content-type, but if none is set then the HTTP adapter sets this to 
          # application/x-www-form-urlencoded and issues a warning about it.
          if METHODS_WITH_BODIES.include?(http_method.to_s)
            headers['Content-Type'] = FALLBACK_CONTENT_TYPE
          end
        end
      end
      headers.update(self.headers)
      body = self.body

      ur = nil
      conn = faraday_connection(-> (yur) { ur = yur })
      conn.run_request(http_method.downcase.to_sym, url, body, headers)
      ur.scorpio_request = self
      ur
    end

    # runs this request. returns the response body object - that is, the response body
    # parsed according to an understood media type, and instantiated with the applicable
    # response schema if one is specified. see {Scorpio::Response#body_object} for more detail.
    #
    # @param mutable (see Response#body_object)
    # @raise [Scorpio::HTTPError] if the request returns a 4xx or 5xx status, the appropriate
    #   error is raised - see {Scorpio::HTTPErrors}
    def run(mutable: false)
      ur = run_ur
      ur.raise_on_http_error
      ur.response.body_object(mutable: mutable)
    end

    # Runs this request, passing the resulting Ur to the given block.
    # The `next_page` callable is then called with that Ur and results in the next page's Ur, or nil.
    # This repeats until the `next_page` call results in nil.
    #
    # See {OpenAPI::Operation#each_link_page} for integration with an OpenAPI Operation.
    #
    # @param next_page [#call] a callable which will take a parameter `page_ur`, which is a {Scorpio::Ur},
    #   and must result in an Ur representing the next page, which will be yielded to the block.
    # @yield [Scorpio::Ur] yields the first page, and each subsequent result of calls to `next_page` until
    #   that results in nil
    # @return [Enumerator, nil]
    def each_page_ur(next_page: , raise_on_http_error: true)
      return to_enum(__method__, next_page: next_page, raise_on_http_error: raise_on_http_error) unless block_given?
      page_ur = run_ur
      while page_ur
        unless page_ur.is_a?(Scorpio::Ur)
          raise(TypeError, [
            "next_page must result in a #{Scorpio::Ur}",
            "this should be the result of #run_ur from a #{OpenAPI::Operation} or #{Request}",
          ].join("\n"))
        end
        page_ur.raise_on_http_error if raise_on_http_error
        yield page_ur
        page_ur = next_page.call(page_ur)
      end
      nil
    end
  end
end
