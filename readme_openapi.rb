#!/usr/bin/env ruby
# frozen_string_literal: true

# a small script following the code samples in the README
# section: Pet Store (without Scorpio::ResourceBase)

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), 'lib'))
require 'scorpio'

puts "pet_store_oad: instantiating pet store OpenAPI document"

pet_store_content = JSON.parse(Faraday.get('https://petstore.swagger.io/v2/swagger.json').body)
pet_store_oad = Scorpio::OpenAPI::Document.from_instance(pet_store_content)
# => #{<JSI (Scorpio::OpenAPI::V2::Document)> "swagger" => "2.0", ...}

puts

# the store inventory operation will let us see what statuses there are in the store.
inventory_op = pet_store_oad.paths['/store/inventory']['get']
# => #{<JSI (Scorpio::OpenAPI::V2::Operation)>
#      "summary" => "Returns pet inventories by status",
#      "operationId" => "getInventory",
#      ...
#    }

inventory_op = pet_store_oad.operations['getInventory']
# => returns the same inventory_op as above.

inventory = inventory_op.run
print "inventory = pet_store_oad.operations['getInventory'].run: "
pp inventory
puts

# call the operation findPetsByStatus
# doc: https://petstore.swagger.io/#/pet/findPetsByStatus
sold_pets = pet_store_oad.operations['findPetsByStatus'].run(status: 'sold', mutable: true)
# sold_pets is an array-like collection of JSI instances
print "sold_pets = pet_store_oad.operations['findPetsByStatus'].run(status: 'sold', mutable: true): "
pp sold_pets.first(3) # 3 is plenty
puts '...'
puts


pet = sold_pets.detect { |pet| pet.tags.any? }
print 'pet = sold_pets.sample: '
pp pet
puts

puts 'pet.tags.map(&:name): ' +
      pet.tags.map(&:name).inspect
# note that you have accessors on the returned JSI like #tags, and also that
# tags have accessors for properties 'name' and 'id' from the tags schema
# (your tag names will be different depending on what's in the pet store)
puts

# compare the pet from findPetsByStatus to one returned from getPetById
# doc: https://petstore.swagger.io/#/pet/getPetById
pet_by_id = pet_store_oad.operations['getPetById'].run(petId: pet['id'])
print "pet_by_id = pet_store_oad.operations['getPetById'].run(petId: pet['id']): "
pp pet_by_id
puts

# unlike ResourceBase instances above, JSI instances have stricter
# equality and the pets returned from different operations are not
# equal, though the underlying JSON instance is.
puts "pet_by_id == pet: " +
     (pet_by_id == pet).inspect

puts "pet_by_id.jsi_instance == pet.jsi_instance: " +
     (pet_by_id.jsi_instance == pet.jsi_instance).inspect

# let's name the pet after ourself
pet.name = ENV['USER']
puts "pet.name = ENV['USER']"
print 'pet: '
pp pet
puts

# store the result in the pet store.
# updatePet: http://petstore.swagger.io/#/pet/updatePet
print "pet_store_oad.operations['updatePet'].run(body_object: pet): "
pp pet_store_oad.operations['updatePet'].run(body_object: pet)
puts

# check that it was saved
puts "pet_store_oad.operations['getPetById'].run(petId: pet['id']).name: " +
      pet_store_oad.operations['getPetById'].run(petId: pet['id']).name.inspect
puts

puts "pet_store_oad.operations['getPetById'].run(petId: 0): "
begin
  # here is how errors are handled:
  pet_store_oad.operations['getPetById'].run(petId: 0)
  # raises: Scorpio::HTTPErrors::NotFound404Error
  #   Error calling operation getPetById on PetStore::Pet:
  #   {"code":1,"type":"error","message":"Pet not found"}
rescue
  pp $!
end
