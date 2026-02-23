# frozen_string_literal: true

module Scorpio
  module Google
    discovery_rest_description_doc = YAML.safe_load(Scorpio.root.join('documents/www.googleapis.com/discovery/v1/apis/discovery/v1/rest.yml').read)
    DISCOVERY_REST_DESCRIPTION = JSI.new_metaschema_node(
      discovery_rest_description_doc,
      dialect: JSI::Schema::Draft04::DIALECT,
      metaschema_root_ref: "#/schemas/JsonSchema",
      root_schema_ref: "#/schemas/RestDescription",
    )

    # naming these is not strictly necessary, but is nice to have.


    DirectoryList = DISCOVERY_REST_DESCRIPTION.schemas['DirectoryList'].jsi_schema_module
    JsonSchema     = DISCOVERY_REST_DESCRIPTION.schemas['JsonSchema'].jsi_schema_module
    RestDescription = DISCOVERY_REST_DESCRIPTION.schemas['RestDescription'].jsi_schema_module
    RestMethod     = DISCOVERY_REST_DESCRIPTION.schemas['RestMethod'].jsi_schema_module
    RestResource  = DISCOVERY_REST_DESCRIPTION.schemas['RestResource'].jsi_schema_module

    module RestDescription
      Resources = properties['resources']
    end

    module RestMethod
      Request = properties['request']
      Response = properties['response']

      # these only contain a $ref to a schema, but that is enough to use them as schemas
      Request.schema.describes_schema!([JSI::Schema::Draft04])
      Response.schema.describes_schema!([JSI::Schema::Draft04])
    end

    module HasMethodsAndResources
      def operations
        return @operations if instance_variable_defined?(:@operations)
        @operations = OpenAPI::OperationsScope.new(each_operation)
      end

      def each_operation(&block)
        return(to_enum(__method__)) unless block

        (self['methods'] || {}).each_value(&block)

        (self['resources'] || {}).each_value do |resource|
          resource.each_operation(&block)
        end
      end
    end

    module RestDescription
      include(OpenAPI::Document)
      include(HasMethodsAndResources)

      attr_writer(:base_url)

      def base_url(scheme: nil, server: nil, server_variables: nil)
        return @base_url if instance_variable_defined?(:@base_url)
        JSI::Util.uri(rootUrl ? File.join(rootUrl, servicePath) : baseUrl) # baseUrl is deprecated
      end

      def title
        self['title'] # override OpenAPI::Document#title
      end
    end

    module RestResource
      include(HasMethodsAndResources)
    end

    module RestMethod
      include(OpenAPI::Operation)

      def tagged?(tag_name)
        resource_names.include?(tag_name)
      end

      def resource_names
        # resource name is the property name where a RestResource is. kind of hax but it works.
        jsi_parent_nodes.select { |n| n.is_a?(RestResource) }.map { |r| r.jsi_ptr.tokens.last }
      end

      def path_template_str
        path
      end

      def parameters
        (self['parameters'] || {}).map do |name, schema|
          param = {'name' => name}
          param['in'] = schema.location if schema.key?('location')
          param['schema'] = schema
          #param['description'] = schema.description if schema.key?('description')
          #param['required'] = schema.required if schema.key?('required')
          param
        end
      end

      def request_media_type
        'application/json'
      end

      def http_method
        httpMethod
      end

      def openapi_document
        rest_description
      end

      def rest_description
        jsi_parent_nodes.detect { |p| p.is_a?(RestDescription) }
      end

      def scheme
        nil
      end

      def server
        nil
      end

      def server_variables
        nil
      end

      def operationId
        id
      end

      # @param media_type unused
      def request_schema(media_type: nil)
        request
      end

      def request_schemas
        request ? [request] : []
      end

      def response_schema(status: nil, media_type: nil)
        response
      end

      def response_schemas
        response ? [response] : []
      end
    end
  end
end
