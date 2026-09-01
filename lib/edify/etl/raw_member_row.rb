module Edify
  module Etl
    RawMemberRow = Struct.new(:name, :gender, :birthdate, :phone_number, :email, :baptized)
  end
end
