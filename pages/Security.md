# API Security

Scorpio does not currently implement an interface for any particular API security mechanism, which an OpenAPI description might specify using an operation's Security Requirement and corresponding Security Scheme. Scorpio offers flexibility in how applications may authenticate using common mechanisms - for more general guidance see {file:Request_Configuration Request Configuration}.

### Authorization header

An authorization header can be set using the `authorization` configuration on an OpenAPI document, operation, or request:

```ruby
# applies to every request (unless overridden per operation or request)
my_openapi_document.authorization = "Basic bm90RXRoYW46cDRzc3cwcmQ"

# or, applying to every request from my_operation (unless overridden)
my_operation.authorization = "Basic bm90RXRoYW46cDRzc3cwcmQ"

# or, per request:
my_operation.run(authorization: "Basic bm90RXRoYW46cDRzc3cwcmQ")
```

### Another header

Any other request headers can be set similarly:

```ruby
# document
my_openapi_document.request_headers = {"Api-Key" => "bm90RXRoYW46cDRzc3cwcmQ"}

# operation
my_operation.request_headers = {"Api-Key" => "bm90RXRoYW46cDRzc3cwcmQ"}

# request (note: just `headers` not `request_headers` here)
my_operation.run(headers: {"Api-Key" => "bm90RXRoYW46cDRzc3cwcmQ"})
```

### Faraday request middleware

Faraday middleware can be used to set headers or other components of the request, by configuring `faraday_builder`. If authentication must be computed for each request (e.g. by including a signature of the request), configured Faraday middleware is invoked for each request. Faraday middleware libraries exist for common authentication mechanisms - see [awesome-faraday](https://github.com/lostisland/awesome-faraday).

```ruby
# document
my_openapi_document.faraday_builder = proc do |faraday_connection|
  faraday_connection.request(:authorization, :basic, 'notEthan', 'p4ssw0rd')
end

# operation
my_operation.faraday_builder = proc { |c| c.request(:authorization, :basic, 'notEthan', 'p4ssw0rd') }

# request
my_operation.run(faraday_builder: proc { |c| c.request(:authorization, :basic, 'notEthan', 'p4ssw0rd') })
```
