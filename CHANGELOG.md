# v0.6.1
- compatibility
  - JSI 0.7
  - Faraday 2
  - Ruby 3
  - JRuby

# v0.6.0
- ResourceBase resources in responses may be contained anywhere in the response object contained in ResourceBase::Container
- ResourceBase defines class methods for operations whose request or response schemas are represented by the resource
- JSI v0.6.0

# v0.5.0
- JSI schema classes change to schema modules, JSI instances may have multiple schemas (JSI v0.4, Ur v0.2)

# v0.4.6
- JSI v0.3.0
- Scorpio::OpenAPI::SchemaReference represents a schema reference
- Scorpio::OpenAPI::Reference implicitly derefs

# v0.4.5
- Ur v0.1.0
- misc

# v0.4.4
- JSI v0.2.0
- misc

# v0.4.3
- misc

# v0.4.2
- improve documentation
- misc bugfixes

# v0.4.1
- Request#param_for
- Operation#human_id
- bugfixes

# v0.4.0
- Scorpio::OpenAPI v3 classes updated from OAI/OpenAPI-Specification branch oas3-schema
- any uniquely-named request parameter will have accessors on Request and can be passed as config to #initialize
- Request#each_page_ur for pagination
- significantly improved documentation
- many refactorings, improvements, and fixes

# v0.3.1
- miscellaneous minor fixes and improvements

# v0.3.0
- OpenAPI v3 support
- classes Request/Response, OpenAPI::Operation, OpenAPI::Document handle a request. ResourceBase relies on these.
- extract SchemaInstanceBase and friends to gem JSI

# v0.2.3
- fix mutability of SchemaInstanceBase with #[]=; instance is modified in place
- add mutability to JSON::Node with #[]=
- fix problems with initialize extending SchemaInstanceBase instances with Enumerable; just include it on SchemaInstanceBase itself

# v0.2.2
- Scorpio::SchemaInstanceJSONCoder

# v0.2.1
- SchemaInstanceBase#parent, #parents
- compatibility fix #as_json

# v0.2.0

# v0.1.0

- Rewrite Model, use OpenAPI
- abstraction for a schema, Scorpio::Schema
- abstraction for a json node at a path within its document, Scorpio::JSON::Node
- abstraction for an object represented by a schema, Scorpio::SchemaObjectBase
- so much more

# v0.0.2

- Scorpio::Model minor bugfixes and refactoring

# v0.0.1

- initial Scorpio::Model
- initial Scorpio::Model::PickleAdapter
