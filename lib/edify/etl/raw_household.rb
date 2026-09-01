module Edify
  module Etl
    RawHousehold = Struct.new(:name, :address_lines, :phone_number, :email, :people)

    # One name listed under a household. The directory shows an age only for the younger members, so a blank
    # `listed_age` says nothing about how old someone is.
    RawHouseholdEntry = Struct.new(:name, :listed_age, :parent)
  end
end
