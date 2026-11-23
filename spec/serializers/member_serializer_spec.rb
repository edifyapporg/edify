require "rails_helper"

RSpec.describe ::MemberSerializer do
  it "gives name, gender and age group only" do
    member = ::Member.new(name: "Doe, Jane", gender: :female, birthdate: 9.years.ago.to_date,
                          email: "jane@example.com", phone_number: "303-555-0100")

    expect(described_class.call(member)).to eq(name: "Doe, Jane", gender: "female", group: "primary")
  end
end
