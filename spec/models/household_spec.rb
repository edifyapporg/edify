require "rails_helper"

describe Household do
  let(:unit) { units(:sunny_hills) }
  let(:household) do
    unit.households.create!(name: "Bins, Froederick & Lisette",
                            address_lines: ["1433 N 1500 E", "Provo UT 84604-3712"])
  end

  it "requires a name that is unique within the unit" do
    household
    duplicate = unit.households.new(name: household.name)

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:name]).to be_present
  end

  it "joins its address lines for display" do
    expect(household.address).to eq("1433 N 1500 E\nProvo UT 84604-3712")
  end

  it "knows the surname its first-name-only people belong to" do
    expect(household.surname).to eq("Bins")
  end

  it "lists its people in the order the directory gave them" do
    %w[Lisette Froederick].each_with_index do |name, index|
      household.household_members.create!(name: "Bins, #{name}", position: 1 - index)
    end

    expect(household.household_members.map(&:name)).to eq(["Bins, Froederick", "Bins, Lisette"])
  end

  it "singles out the adults it is named for" do
    household.household_members.create!(name: "Bins, Froederick", position: 0, parent: true)
    household.household_members.create!(name: "Bins, Hildy", position: 1, listed_age: 14)

    expect(household.parents.map(&:name)).to eq(["Bins, Froederick"])
  end

  it "takes its people with it when it is destroyed" do
    household.household_members.create!(name: "Bins, Froederick", position: 0)

    expect { household.destroy }.to change(HouseholdMember, :count).by(-1)
  end
end
