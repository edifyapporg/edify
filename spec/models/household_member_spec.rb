require "rails_helper"

describe HouseholdMember do
  let(:unit) { units(:sunny_hills) }
  let(:household) { unit.households.create!(name: "Bins, Froederick & Lisette") }
  let(:member) { members(:hill_waylon) }

  it "stands on its own without a member record" do
    entry = household.household_members.create!(name: "Bins, Wanda", position: 0, listed_age: 7)

    expect(entry).to be_valid
    expect(entry.member).to be_nil
  end

  it "treats a listed age as the directory's way of marking a minor" do
    minor = household.household_members.create!(name: "Bins, Hildy", position: 0, listed_age: 14)
    adult = household.household_members.create!(name: "Bins, Froederick", position: 1)

    expect(minor).to be_minor
    expect(adult).not_to be_minor
  end

  it "separates the linked from the unlinked" do
    linked = household.household_members.create!(name: member.name, position: 0, member: member)
    unlinked = household.household_members.create!(name: "Bins, Wanda", position: 1)

    expect(described_class.matched).to include(linked)
    expect(described_class.matched).not_to include(unlinked)
    expect(described_class.unmatched).to include(unlinked)
  end

  it "outlives the member it points at" do
    entry = household.household_members.create!(name: member.name, position: 0, member: member)

    member.destroy

    expect(entry.reload.member_id).to be_nil
    expect(entry.name).to eq(member.name)
  end
end
