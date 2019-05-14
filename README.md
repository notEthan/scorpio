# Scorpio

[![Build Status](https://travis-ci.org/notEthan/scorpio.svg?branch=master)](https://travis-ci.org/notEthan/scorpio)
[![Coverage Status](https://coveralls.io/repos/github/notEthan/scorpio/badge.svg)](https://coveralls.io/github/notEthan/scorpio)

Scorpio is a library that helps you, as a client, consume an HTTP service described by an OpenAPI document. You provide the OpenAPI specification, a little bit of configuration, and Scorpio will take that and dynamically generate an interface for you to call the service's operations and interact with its resources as an ORM.

Note: The canonical location of this README is on [RubyDoc](http://rubydoc.info/gems/scorpio/). When viewed on [Github](https://github.com/notEthan/scorpio/), it may be inconsistent with the latest released gem, and Yardoc links will not work.

## Background

To start with, you need an OpenAPI (formerly known as Swagger) document describing a service you will be consuming. v2 and v3 are both supported.[^1] This document can be written by hand or sometimes generated from other existing sources. The creation of an OpenAPI document specifying your service is outside the scope of Scorpio. Here are several resources on OpenAPI:

- [OpenAPI Specification at Wikipedia](https://en.wikipedia.org/wiki/OpenAPI_Specification)
- [OpenAPI Initiative](https://www.openapis.org/) is the official web site for OpenAPI
- [OpenAPI Specification on GitHub](https://github.com/OAI/OpenAPI-Specification)
- [swagger.io](https://swagger.io/) API tooling

OpenAPI relies on the definition of schemas using the JSON schema specification, which can be learned about at https://json-schema.org/

Once you have the OpenAPI document describing the service you will consume, you can get started implementing the code that will interact with that service.

[^1]: Certain features may be missing, but Scorpio tries to make workarounds easy. Issues and pull requests regarding missing functionality are welcome.

## Pet Store (using Scorpio::ResourceBase)

Let's dive into some code, shall we? If you have learned about OpenAPI, you likely learned using the example of the Pet Store service. This README will use the same service. Its documentation is at http://petstore.swagger.io/.

Using the specification, we can start interacting with the pet store with very little code. Here is that code, with explanations of each part in the comments.

```ruby
require 'scorpio'
# PetStore is a module to contain our pet store related classes.
# it is optional - your naming conventions are your own.
module PetStore
  # Scorpio's recommended structure is to have a base class which inherits from
  # Scorpio::ResourceBase to represent the Pet Store and all its resources.
  #
  # you configure the openapi document and other shared configuration on this class.
  class Resource < Scorpio::ResourceBase
    # set the openapi document. you'll usually want this to be a file in your local filesystem
    # (making network calls at application boot time is usually a bad idea), but for this
    # example we will do a quick-and-dirty http get.
    require 'json'
    self.openapi_document = JSON.parse(Faraday.get('http://petstore.swagger.io/v2/swagger.json').body)
  end

  # a Pet is a resource of the pet store, so inherits from PetStore::Resource
  class Pet < Resource
    # setting the tag name tells Scorpio to associate operations tagged with 'pet' with this
    # class and its instances. this lets you call operations such as addPet, updatePet, etc.
    self.tag_name = 'pet'

    # setting the schemas which represent a Pet will let scorpio return results from operation
    # calls properly instantiated as Pet instances. for example, calling getPetById will return
    # a PetStore::Pet instance since its success response refers to #/definitions/Pet.
    #
    # this works for nested structures as well, e.g. findPetsByStatus returns an array of
    # #/definitions/Pet and likewise Scorpio will return an array of PetStore::Pet instances.
    #
    # this also adds accessors for properties of the schema - in this case #id, #name, #tags, etc.
    self.represented_schemas = [openapi_document.definitions['Pet']]
  end
end
```

That should be all you need to start calling operations:

```ruby
# call the operation findPetsByStatus: http://petstore.swagger.io/#/pet/findPetsByStatus
sold_pets = PetStore::Pet.findPetsByStatus(status: 'sold')
# sold_pets is an array-like collection of PetStore::Pet instances

# compare to getPetById: http://petstore.swagger.io/#/pet/getPetById
pet1 = sold_pets.last
pet2 = PetStore::Pet.getPetById(petId: pet1['id'])
# pet2 is the same pet as pet1, retrieved using the getPetById operation

pet1 == pet2
# should return true. they are the same pet.

pet1.tags.map(&:name)
# note that you have accessors on PetStore::Pet like #tags, and also that
# tags have accessors for properties 'name' and 'id' from the tags schema
# (your tag names will be different depending on what's in the pet store)
# => ["aucune"]

# let's name the pet after ourself
pet1.name = ENV['USER']

# store the result in the pet store. note the updatePet call from the instance - our
# calls so far have been on the class PetStore::Pet, but scorpio defines instance
# methods to call operations where appropriate as well.
# updatePet: http://petstore.swagger.io/#/pet/updatePet
pet1.updatePet

# check that it was saved
PetStore::Pet.getPetById(petId: pet1['id']).name
# => "ethan" (unless for some reason your name is not Ethan)

# here is how errors are handled:
PetStore::Pet.getPetById(petId: 0)
# raises: Scorpio::HTTPErrors::NotFound404Error
#   Error calling operation getPetById on PetStore::Pet:
#   {"code":1,"type":"error","message":"Pet not found"}
```

Isn't that cool? You get class methods like getPetById, instance methods like updatePet, attribute accessors like #name and #tags, all dynamically generated from the OpenAPI description. You just make a few classes with a line or two of configuration in each.

## Pet Store (using Scorpio::OpenAPI classes)

You do not have to define resource classes to use Scorpio to call OpenAPI operations - the classes Scorpio uses to represent concepts from OpenAPI can be called directly. Scorpio uses [JSI](https://github.com/notEthan/ur) classes to represent OpenAPI schemes such as the Document and its Operations.

We start by instantiating the OpenAPI document. `Scorpio::OpenAPI::Document.from_instance` returns a V2 or V3 OpenAPI Document class instance.

```ruby
require 'scorpio'
pet_store_doc = Scorpio::OpenAPI::Document.from_instance(JSON.parse(Faraday.get('http://petstore.swagger.io/v2/swagger.json').body))
# => #{<Scorpio::OpenAPI::V2::Document fragment="#"> "swagger" => "2.0", ...}
```

The OpenAPI document holds the JSON that represents it, so to get an Operation you go through the document's paths, just as it is represented in the JSON.

```ruby
# the store inventory operation will let us see what statuses there are in the store.
inventory_op = pet_store_doc.paths['/store/inventory']['get']
# => #{<Scorpio::OpenAPI::V2::Operation fragment="#/paths/~1store~1inventory/get">
#      "summary" => "Returns pet inventories by status",
#      "operationId" => "getInventory",
#      ...
#    }
```

Alternatively, Scorpio defines a helper `Document#operations` which behaves like an Enumerable of all the Operations in the Document. It can be subscripted with the `operationId`:

```ruby
inventory_op = pet_store_doc.operations['getInventory']
# => returns the same inventory_op as above.
```

Now that we have an operation, we can run requests from it. {Scorpio::OpenAPI::Operation#run} performs the operation by running a request. If the response is an error, a {Scorpio::HTTPError} subclass will be raised. On success, it returns the response body entity, instantiated according to the OpenAPI schema for the operation response, if specified. For more detail on how json-schema instances are represented, see the gem [JSI](https://github.com/notEthan/jsi).

```ruby
inventory = inventory_op.run
# => #{<JSI::SchemaClasses["dde3#/paths/~1store~1inventory/get/responses/200/schema"] fragment="#">
#      "unavailable" => 4,
#      "unloved - needs a home" => 1,
#      "available" => 2350,
#      "sold" => 5790,
#      "dog" => 1,
#    }
```

let's pick a state and find a pet. we'll go through the rest of the example in the ResourceBase section pretty much like it is up there:

```ruby
# call the operation findPetsByStatus: http://petstore.swagger.io/#/pet/findPetsByStatus
sold_pets = pet_store_doc.operations['findPetsByStatus'].run(status: 'sold')
# sold_pets is an array-like collection of JSI instances

# compare to getPetById: http://petstore.swagger.io/#/pet/getPetById
pet1 = sold_pets.detect { |pet| pet.tags.any? }
pet2 = pet_store_doc.operations['getPetById'].run(petId: pet1['id'])
# without ResourceBase, pet1 and pet2 are not considered to be the same though [TODO may change in jsi]

pet1 == pet2
# false

pet1.tags.map(&:name)
# note that you have accessors on PetStore::Pet like #tags, and also that
# tags have accessors for properties 'name' and 'id' from the tags schema
# (your tag names will be different depending on what's in the pet store)
# => ["aucune"]

# let's name the pet after ourself
pet1.name = ENV['USER']

# store the result in the pet store.
# updatePet: http://petstore.swagger.io/#/pet/updatePet
pet_store_doc.operations['updatePet'].run(body_object: pet1)

# check that it was saved
pet_store_doc.operations['getPetById'].run(petId: pet1['id']).name
# => "ethan" (unless for some reason your name is not Ethan)

# here is how errors are handled:
pet_store_doc.operations['getPetById'].run(petId: 0)
# raises: Scorpio::HTTPErrors::NotFound404Error
#   Error calling operation getPetById:
#   {"code":1,"type":"error","message":"Pet not found"}
```

### Another Example: Blog

For another example of an API that a client interacts with using Scorpio::ResourceBase, Scorpio's tests implement the Blog service. This is defined in test/blog.rb. The service uses ActiveRecord models and Sinatra to make a simple RESTful service.

Its API is described in `test/blog.openapi.yml`, defining the Article resource, several operations, and schemas. The client is set up in `test/blog_scorpio_models.rb`. The base class BlogModel defines the base_url and the api description, as well as some other optional setup done for testing. Its operations are tested in `test/scorpio_test.rb`.

## Scorpio::ResourceBase

Scorpio::ResourceBase is the main class used in abstracting on OpenAPI document. Scorpio::ResourceBase aims to represent RESTful resources in ruby classes with as little code as possible, given a service with a properly constructed OpenAPI specification.

A class which subclasses Scorpio::ResourceBase directly (such as PetStore::Resource above) should generally represent the whole API - you set the openapi_document and other configuration on this class. As such, it is generally not instantiated. Its subclasses, representing resources with a tag or with schema definitions in the OpenAPI document, are what you mostly instantiate and interact with.

A model representing a resource needs to be configured, minimally, with:

- the OpenAPI specification for the REST API
- the schemas that represent instances of the model, if any

If the resource has HTTP operations associated with it (most, but not all resources will):

- a tag name identifying its tagged operations

When these are set, Scorpio::ResourceBase looks through the API description and dynamically sets up methods for the model:

- accessors for properties of the model defined as properties of schemas representing the resource in the specification
- API method calls on the model class and, where appropriate, on the model instance

## Scorpio::Ur

If you need a more complete representation of the HTTP request and/or response, Scorpio::OpenAPI::Operation#run_ur or Scorpio::Request#run_ur will return a representation of the request and response defined by the gem [Ur](https://github.com/notEthan/ur). See that link for more detail. Relating to the example above titled "Pet Store (using Scorpio::OpenAPI classes)", this code will return an Ur:

```ruby
inventory_op = Scorpio::OpenAPI::Document.from_instance(JSON.parse(Faraday.get('http://petstore.swagger.io/v2/swagger.json').body)).paths['/store/inventory']['get']
inventory_ur = inventory_op.run_ur
# => #{<Scorpio::Ur fragment="#"> ...}
```

### Scorpio ResourceBase pickle adapter

Scorpio provides a pickle adapter to use models with [Pickle](https://rubygems.org/gems/pickle). `require 'scorpio/pickle_adapter'`, ensure that the pickle ORM adapter is enabled, and you should be able to create models as normal with pickle.

### Google API discovery service

An initial implementation of Scorpio::ResourceBase was based on the format defined for Google's API discovery service.

For background on the Google discovery service and the API description format it defines, see:

- https://developers.google.com/discovery/
- https://developers.google.com/discovery/v1/reference/

This format is still supported indirectly, by converting from a Google API document to OpenAPI using `Scorpio::Google::RestDescription#to_openapi_document`. Example conversion looks like:

```ruby
class MyModel < Scorpio::ResourceBase
  rest_description_doc = YAML.load_file('path/to/doc.yml')
  rest_description = Scorpio::Google::RestDescription.new(rest_description_doc)
  self.openapi_document = rest_description.to_openapi_document

  # ... the remainder of your setup and model code here
end
```

## Other

The detailed, machine-interpretable description of an API provided by a properly-constructed OpenAPI specification opens up numerous possibilities to automate aspects of clients and services to an API. These are planned to be implemented in Scorpio:

- constructing test objects in a manner similar to FactoryBot, allowing you to write tests that depend on a service without having to interact with an actual running instance of that service to run your tests
- rack middleware to test that outgoing HTTP responses are conformant to their response schemas
- rack middleware to test that incoming HTTP requests are conformant to their request schemas, and that the service handles bad requests appropriately (e.g. ensuring that for any bad request, the service responds with a 4xx error instead of 2xx).
- integrating with ORMs to generate HTTP responses that are conformant to the response schema corresponding to the resource corresponding to the ORM model
- generating model validations for ORMs

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
