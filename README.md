# Scorpio

![Test CI Status](https://github.com/notEthan/scorpio/actions/workflows/test.yml/badge.svg?branch=main)
[![Coverage Status](https://coveralls.io/repos/github/notEthan/scorpio/badge.svg)](https://coveralls.io/github/notEthan/scorpio)

Scorpio is a library that helps you, as a client, consume a service whose API is described by an OpenAPI description. You provide the OpenAPI description document, a little bit of configuration, and using that Scorpio will dynamically construct interfaces for you to call the service's operations and interact with its resources like an ORM.

Note: The canonical location of this README is on [RubyDoc](https://rubydoc.info/gems/scorpio/). When viewed on [Github](https://github.com/notEthan/scorpio/), it may be inconsistent with the latest released gem, and Yardoc links will not work.

## Background

### OpenAPI specification and OpenAPI documents

To start with, you need an OpenAPI document (an OAD) describing a service you will be consuming. OpenAPI Specification v3.0 and v2 (formerly known as Swagger) are supported. An OAD can be written by hand or sometimes generated from other existing sources. The creation of an OpenAPI document describing a given service is outside the scope of Scorpio. Here are several resources on OpenAPI:

- [Learn about OpenAPI](https://learn.openapis.org/)
- [OpenAPI Specification at Wikipedia](https://en.wikipedia.org/wiki/OpenAPI_Specification)
- OpenAPI [Specification v2.0](https://spec.openapis.org/oas/v2.0.html) and [Specification v3.0](https://spec.openapis.org/oas/v3.0.html)
- [OpenAPI Specification development on GitHub](https://github.com/OAI/OpenAPI-Specification)

### JSON Schema, JSI

[JSON Schema](https://json-schema.org/) is an important part of OpenAPI documents, in which it is used to describe various components of a service's requests and responses.

[JSI](https://github.com/notEthan/jsi) is a Ruby library that offers an Object-Oriented representation for JSON data using JSON Schemas.

Scorpio utilizes JSI to instantiate components of the API described by JSON schemas, in particular JSON request and response bodies.

Scorpio's core is built on JSI. It uses the JSON Schema describing OpenAPI documents (which is published along with the OpenAPI specification) with JSI to instantiate an OAD and to define functionality of the document, operations, and other components.

## Pet Store (using Scorpio::ResourceBase)

Let's dive into some code, shall we? If you have learned about OpenAPI, you likely learned using the example of the Pet Store service. This README will use the same service. Its documentation is at https://petstore.swagger.io/.

Using the OpenAPI document, we can start interacting with the pet store with very little code. Here is that code, with explanations of each part in the comments.

```ruby
require 'scorpio'
# PetStore is a module to contain our pet store related classes.
# it is optional - your naming conventions are your own.
module PetStore
  # Scorpio's recommended structure is to have a base class which
  # inherits from Scorpio::ResourceBase to represent the Pet Store
  # and all its resources.
  #
  # You configure the OpenAPI document and other shared configuration
  # on this class.
  class Resource < Scorpio::ResourceBase
    # Set the OpenAPI document. You'll usually want this to be a file in
    # your local filesystem (making network calls at application boot
    # time is usually a bad idea), but for this example we will do a
    # quick-and-dirty HTTP get.
    require 'json'
    self.openapi_document = JSON.parse(Faraday.get('https://petstore.swagger.io/v2/swagger.json').body)
  end

  # a Pet is a resource of the pet store, so inherits from
  # PetStore::Resource
  class Pet < Resource
    # Setting the tag name tells Scorpio to associate operations tagged
    # with 'pet' with this class and its instances. This lets you call
    # operations such as addPet, updatePet, etc.
    self.tag_name = 'pet'

    # Setting the schemas which represent a Pet will let Scorpio
    # return results from operation calls properly instantiated as
    # Pet instances. For example, calling getPetById will return a
    # PetStore::Pet instance since its success response refers
    # to #/definitions/Pet.
    #
    # This works for nested structures as well, e.g. findPetsByStatus
    # returns an array of #/definitions/Pet and likewise Scorpio will
    # return an array of PetStore::Pet instances.
    #
    # This also adds accessors for properties of the schema - in this
    # case #id, #name, #tags, etc.
    self.represented_schemas = [openapi_document.definitions['Pet']]
  end
end
```

That is all you need to start calling operations:

```ruby
# call the operation findPetsByStatus
# doc: https://petstore.swagger.io/#/pet/findPetsByStatus
sold_pets = PetStore::Pet.findPetsByStatus(status: 'sold')
# sold_pets is an array-like collection of PetStore::Pet instances

pet = sold_pets.sample

pet.tags.map(&:name)
# note that you have accessors on PetStore::Pet like #tags, and also that
# tags have accessors for properties 'name' and 'id' from the tags schema
# (your tag names will be different depending on what's in the pet store)
# => ["aucune"]

# compare to getPetById: https://petstore.swagger.io/#/pet/getPetById
pet == PetStore::Pet.getPetById(petId: pet['id'])
# pet is the same, retrieved using the getPetById operation

# let's name the pet after ourself
pet.name = ENV['USER']

# Store the result in the pet store. Note the updatePet call from the
# instance - our calls so far have been on the class PetStore::Pet,
# but Scorpio defines instance methods to call operations where
# appropriate as well.
# updatePet: https://petstore.swagger.io/#/pet/updatePet
pet.updatePet

# check that it was saved
PetStore::Pet.getPetById(petId: pet['id']).name
# => "ethan" (unless for some reason your name is not Ethan)

# here is how errors are handled:
PetStore::Pet.getPetById(petId: 0)
# raises: Scorpio::HTTPErrors::NotFound404Error
#   Error calling operation getPetById on PetStore::Pet:
#   {"code":1,"type":"error","message":"Pet not found"}
```

Isn't that cool? You get class methods like getPetById, instance methods like updatePet, attribute accessors like #name and #tags, all dynamically generated from the OpenAPI description. You just make a few classes with a line or two of configuration in each.

## Pet Store (without Scorpio::ResourceBase)

You do not have to define resource classes as above to use Scorpio to interact with a service - ResourceBase is a helpful representation of the service's resources, but operations can be run directly from Scorpio's representation of the OpenAPI document.

This representation uses [JSI](https://github.com/notEthan/jsi) with the JSON schema describing OpenAPI documents (for the relevant version of the OpenAPI specification). Scorpio's API client functionality is implemented using these schemas, and the result is that the instantiated OpenAPI document is itself the client to the service it describes.

To consume the Pet Store service, we start by instantiating the OpenAPI document. {Scorpio::OpenAPI::Document.from_instance} returns a JSI instance described by the appropriate V2 or V3 OpenAPI document schema.

```ruby
require 'scorpio'
pet_store_content = JSON.parse(Faraday.get('https://petstore.swagger.io/v2/swagger.json').body)
pet_store_doc = Scorpio::OpenAPI::Document.from_instance(pet_store_content)
# => #{<JSI (Scorpio::OpenAPI::V2::Document)> "swagger" => "2.0", ...}
```

Within `pet_store_doc` we can access an operation under the OAD's `#paths` property - JSI objects have accessors for described properties, or can be subscripted as with the Hash/Array nodes they represent.

```ruby
# The store inventory operation will let us see what statuses there are
# in the store.
inventory_op = pet_store_doc.paths['/store/inventory']['get']
# => #{<JSI (Scorpio::OpenAPI::V2::Operation)>
#      "summary" => "Returns pet inventories by status",
#      "operationId" => "getInventory",
#      ...
#    }
```

Alternatively, Scorpio defines a helper {Scorpio::OpenAPI::Document#operations} which is an Enumerable of all the Operations in the Document. It can be subscripted with an `operationId`:

```ruby
inventory_op = pet_store_doc.operations['getInventory']
# => returns the same inventory_op as above.
```

Now that we have an operation, we can run requests from it with {Scorpio::OpenAPI::Operation#run}. On success, it returns the parsed response body, instantiated using the JSON schema for the operation response, if that is specified in the OAD.

```ruby
inventory = inventory_op.run
# => #{<JSI>
#      "unavailable" => 4,
#      "unloved - needs a home" => 1,
#      "available" => 2350,
#      "sold" => 5790,
#      "dog" => 1,
#    }
```

We'll pick a state, find a pet, and go through the rest of the example in the ResourceBase section pretty much like it is up there:

```ruby
# call the operation findPetsByStatus
# doc: https://petstore.swagger.io/#/pet/findPetsByStatus
sold_pets = pet_store_doc.operations['findPetsByStatus'].run(status: 'sold')
# sold_pets is an array-like collection of JSI instances

pet = sold_pets.detect { |pet| pet.tags.any? }

pet.tags.map(&:name)
# Note that you have accessors on the returned JSI like #tags, and also
# that tags have accessors for properties 'name' and 'id' from the tags
# schema (your tag names will be different depending on what's in the
# pet store).
# => ["aucune"]

# compare the pet from findPetsByStatus to one returned from getPetById
# doc: https://petstore.swagger.io/#/pet/getPetById
pet_by_id = pet_store_doc.operations['getPetById'].run(petId: pet['id'])

# unlike ResourceBase instances above, JSI instances have stricter
# equality and the pets returned from different operations are not
# equal, because they are in different JSON documents.
pet_by_id == pet
# => false

# let's name the pet after ourself
pet.name = ENV['USER']

# store the result in the pet store.
# updatePet: https://petstore.swagger.io/#/pet/updatePet
pet_store_doc.operations['updatePet'].run(body_object: pet)

# check that it was saved
pet_store_doc.operations['getPetById'].run(petId: pet['id']).name
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

Scorpio::ResourceBase is the main class used in abstracting on OpenAPI document. Scorpio::ResourceBase aims to represent RESTful resources in ruby classes with as little code as possible, given a service with a properly constructed OpenAPI document.

A class which subclasses Scorpio::ResourceBase directly (such as PetStore::Resource above) should generally represent the whole API - you set the openapi_document and other configuration on this class. As such, it is generally not instantiated. Its subclasses, representing resources with a tag or with schema definitions in the OpenAPI document, are what you mostly instantiate and interact with.

A model representing a resource needs to be configured, minimally, with:

- the OpenAPI document describing the API
- the schemas that represent instances of the model, if any

If the resource has HTTP operations associated with it (most, but not all resources will):

- a tag name identifying its tagged operations

When these are set, Scorpio::ResourceBase looks through the API description and dynamically sets up methods for the model:

- accessors for properties of the model defined as properties of schemas representing the resource in the description document
- API method calls on the model class and, where appropriate, on the model instance

## Scorpio::Ur

If you need a more complete representation of the HTTP request and/or response, Scorpio::OpenAPI::Operation#run_ur or Scorpio::Request#run_ur will return a representation of the request and response defined by the gem [Ur](https://github.com/notEthan/ur). See that link for more detail. Relating to the example above titled "Pet Store (using Scorpio::OpenAPI classes)", this code will return an Ur:

```ruby
inventory_op = Scorpio::OpenAPI::Document.from_instance(JSON.parse(Faraday.get('https://petstore.swagger.io/v2/swagger.json').body)).paths['/store/inventory']['get']
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

The detailed, machine-interpretable description of an API provided by a properly-constructed OpenAPI document opens up numerous possibilities to automate aspects of clients and services to an API. These are planned to be implemented in Scorpio:

- constructing test objects in a manner similar to FactoryBot, allowing you to write tests that depend on a service without having to interact with an actual running instance of that service to run your tests
- rack middleware to test that outgoing HTTP responses are conformant to their response schemas
- rack middleware to test that incoming HTTP requests are conformant to their request schemas, and that the service handles bad requests appropriately (e.g. ensuring that for any bad request, the service responds with a 4xx error instead of 2xx).
- integrating with ORMs to generate HTTP responses that are conformant to the response schema corresponding to the resource corresponding to the ORM model
- generating model validations for ORMs

## License

[<img align="right" src="https://www.gnu.org/graphics/agplv3-155x51.png">](https://www.gnu.org/licenses/agpl-3.0.html)

Scorpio is licensed under the terms of the [GNU Affero General Public License version 3](https://www.gnu.org/licenses/agpl-3.0.html).

Unlike the MIT or BSD licenses more commonly used with Ruby gems, this license requires that if you modify Scorpio and propagate your changes, e.g. by including it in a web application, your modified version must be publicly available. The common path of forking on Github should satisfy this requirement.
