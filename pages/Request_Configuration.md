# Request Configuration

Scorpio aims to offer flexibility in how applications can configure requests. Requests are initiated from an Operation object (e.g. {Scorpio::OpenAPI::Operation#run}), utilizing the Operation and the OpenAPI document that contains it for configuration. Many configurable attributes can be set with varying granularity, on the document (applying to all requests from all operations, unless overridden), on the operation (applying to all requests from that operation), or on the request itself.

Configurable attributes are defined and documented on the module {Scorpio::Request::Configurables}. Modules {Scorpio::OpenAPI::Document::Configurables} and {Scorpio::OpenAPI::Operation::Configurables} define configurable attributes of a document and an operation, respectively, and document their relationship to Request configurables.

{Scorpio::Request#initialize} and methods that instantiate a request (such as {Scorpio::OpenAPI::Operation#run}) take a keyword hash of configuration, which may include attributes defined on the Configurables module, or parameters defined by the operation (except where parameter names conflict with configurable attributes, or are ambiguous).

So for example, given this OpenAPI document:

```yaml
openapi: 3.1.0
info: {title: example, version: '1'}
servers:
- url: "https://{subdomain}.example.com/v1"
  variables:
    subdomain:
      default: api
paths:
  '/foos/{id}':
    patch:
      operationId: foos.patch
      parameters:
        - name: id
          in: path
          required: true
          schema:
            type: string
  '/bars/{id}':
    patch:
      operationId: bars.patch
      parameters:
        - name: id
          in: path
          required: true
          schema:
            type: string
        - name: id
          in: query
          schema:
            type: string
```

then the following Ruby code demonstrates how configuration is inherited from document to operation to request and how parameters are applied.

Note that `build_request` takes the same parameters as `run` or `run_ur` would; it is used since we are not hitting a real API.

```ruby
# instantiate OAD whose content is the same as the yaml above
oad = Scorpio::OpenAPI::Document.from_instance({"openapi"=>"3.1.0", "info"=>{"title"=>"example", "version"=>"1"}, "servers"=>[{"url"=>"https://{subdomain}.example.com/v1", "variables"=>{"subdomain"=>{"default"=>"api"}}}], "paths"=>{"/foos/{id}"=>{"patch"=>{"operationId"=>"foos.patch", "parameters"=>[{"name"=>"id", "in"=>"path", "required"=>true, "schema"=>{"type"=>"string"}}]}}, "/bars/{id}"=>{"patch"=>{"operationId"=>"bars.patch", "parameters"=>[{"name"=>"id", "in"=>"path", "required"=>true, "schema"=>{"type"=>"string"}}, {"name"=>"id", "in"=>"query", "schema"=>{"type"=>"string"}}]}}}})

# configure document level server subdomain
oad.server_variables = {subdomain: 'east'}
# configure operation level server subdomain
oad.operations['bars.patch'].server_variables = {subdomain: 'north'}

# uses document server_variables and sets id as request path param
oad.operations['foos.patch'].build_request(id: 'C7').url
 # https://east.example.com/v1/foos/C7

# sets id as request path param and sets server_variables request config
oad.operations['foos.patch'].build_request(id: 'C7', server_variables: {subdomain: 'west'}).url
# https://west.example.com/v1/foos/C7

# uses operation server_variables. since `id` is a param name in both path and query, `id` alone
# cannot be used as configuration; it must be set on the appropriate params' configurations
oad.operations['bars.patch'].build_request(path_params: {id: 'C7'}, query_params: {id: 'D7'}).url
# https://north.example.com/v1/bars/C7?id=D7
```
