#!/usr/bin/env ruby
# frozen_string_literal: true

# a small script following the code samples in the README
# section: Pet Store (using Scorpio::ResourceBase)

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), 'lib'))
require 'scorpio'

puts "creating PetStore::Resource and PetStore::Pet"
puts

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

puts

# call the operation findPetsByStatus
# doc: https://petstore.swagger.io/#/pet/findPetsByStatus
sold_pets = PetStore::Pet.findPetsByStatus(status: 'sold')
# sold_pets is an array-like collection of PetStore::Pet instances
print "sold_pets = PetStore::Pet.findPetsByStatus(status: 'sold'): "
pp sold_pets.first(3) # 3 is plenty
puts '...'
puts

pet = sold_pets.sample
print 'pet = sold_pets.sample: '
pp pet
puts

puts 'pet.tags.map(&:name): ' +
      pet.tags.map(&:name).inspect
# note that you have accessors on PetStore::Pet like #tags, and also that
# tags have accessors for properties 'name' and 'id' from the tags schema
# (your tag names will be different depending on what's in the pet store)
puts

# compare to getPetById: http://petstore.swagger.io/#/pet/getPetById
puts "pet == PetStore::Pet.getPetById(petId: pet['id']): " +
     (pet == PetStore::Pet.getPetById(petId: pet['id'])).inspect
# pet is the same, retrieved using the getPetById operation

# let's name the pet after ourself
pet.name = ENV['USER']
puts "pet.name = ENV['USER']"
print 'pet: '
pp pet
puts

# Store the result in the pet store. Note the updatePet call from the
# instance - our calls so far have been on the class PetStore::Pet,
# but Scorpio defines instance methods to call operations where
# appropriate as well.
# updatePet: https://petstore.swagger.io/#/pet/updatePet
response = pet.updatePet
print 'pet.updatePet: '
pp response
puts

# check that it was saved
puts "PetStore::Pet.getPetById(petId: pet['id']).name: " +
      PetStore::Pet.getPetById(petId: pet['id']).name.inspect
puts

puts "PetStore::Pet.getPetById(petId: 0): "
begin
  # here is how errors are handled:
  PetStore::Pet.getPetById(petId: 0)
  # raises: Scorpio::HTTPErrors::NotFound404Error
  #   Error calling operation getPetById on PetStore::Pet:
  #   {"code":1,"type":"error","message":"Pet not found"}
rescue
  pp $!
end
