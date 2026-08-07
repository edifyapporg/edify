require "rails_helper"

describe ::DuplicateMemberFinder do
  subject(:pairs) { described_class.call(unit) }

  let(:unit) { ::Unit.create!(name: "Testing Ward", last_synced_on: Date.current) }

  def create_member(name, birthdate:, synced_on: Date.current)
    unit.members.create!(name: name, gender: :male, birthdate: birthdate, synced_on: synced_on)
  end

  it "flags an added middle name and keeps the record still in the latest sync" do
    moved = create_member("Hinkle, Kellianne", birthdate: "1990-01-01", synced_on: 1.day.ago)
    current = create_member("Hinkle, Kellianne Huntington", birthdate: "1990-01-01", synced_on: Date.current)

    expect(pairs.size).to eq(1)
    expect(pairs.first.keep).to eq(current)
    expect(pairs.first.remove).to eq(moved)
  end

  it "flags a surname hyphenation change" do
    a = create_member("Bentley-Dyches, Ben", birthdate: "1985-05-05")
    b = create_member("Dyches, Ben", birthdate: "1985-05-05")

    expect(pairs.size).to eq(1)
    expect([pairs.first.keep, pairs.first.remove].to_set).to eq(Set[a, b])
  end

  it "does not flag same-birthdate members with different first names (e.g. twins)" do
    create_member("Young, John", birthdate: "1970-02-02")
    create_member("Young, Jane", birthdate: "1970-02-02")

    expect(pairs).to be_empty
  end

  it "does not flag related names with different birthdates" do
    create_member("Cole, Sam", birthdate: "1960-03-03")
    create_member("Cole, Samuel", birthdate: "1961-04-04")

    expect(pairs).to be_empty
  end

  it "excludes pairs that have been dismissed" do
    a = create_member("Park, Nicole", birthdate: "1988-08-08")
    b = create_member("Park, Nicole Reese", birthdate: "1988-08-08")
    ::DuplicateDismissal.for(a, b).tap do |d|
      d.unit = unit
      d.dismissed_by = 1
    end.save!

    expect(pairs).to be_empty
  end
end
