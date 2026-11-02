require "rails_helper"
require "edify/etl"

describe ::Edify::Etl::ImportManager do
  # The household directory half of the importer; the individuals half is covered in import_manager_spec.rb.
  let(:unit) { units(:sunny_hills) }
  let(:import_job) { unit.import_jobs.create!(status: :waiting, kind: :households) }

  before do
    import_job.raw_data.attach(io: file_fixture("raw_household_list.txt").open, filename: "raw_data.txt",
                               content_type: "text/plain")
  end

  def import! = described_class.perform!(import_job)

  it "saves a household per record with its address and contact details" do
    expect { import! }.to change(Household, :count).by(4)

    household = unit.households.find_by(name: "Bins, Froederick & Lisette")
    expect(household.address).to eq("1433 N 1500 E\nProvo UT 84604-3712")
    expect(household.phone_number).to eq("(801) 545-4545")
    expect(household.email).to eq("froederick@frank.com")
    expect(household.synced_on).to eq(Date.current)
  end

  it "records everyone the directory lists, in order" do
    import!

    household = unit.households.find_by(name: "Bins, Froederick & Lisette")
    expect(household.household_members.map(&:name))
      .to eq(["Bins, Froederick", "Bins, Lisette", "Bins, Steve", "Bins, Hildy", "Bins, Wanda"])
    expect(household.parents.map(&:name)).to eq(["Bins, Froederick", "Bins, Lisette"])
  end

  it "links a person to their member record when the unit already has one" do
    member = unit.members.create!(name: "Bins, Froederick", gender: :male, birthdate: Date.new(1943, 2, 22))

    import!

    expect(HouseholdMember.find_by(name: "Bins, Froederick").member).to eq(member)
  end

  it "keeps a person the unit has no member record for" do
    import!

    entry = HouseholdMember.find_by(name: "Bins, Wanda")
    expect(entry).to be_present
    expect(entry.member).to be_nil
    expect(entry.listed_age).to eq(7)
  end

  it "refuses to guess when two members share a name" do
    2.times do |i|
      unit.members.create!(name: "Bins, Froederick", gender: :male, birthdate: Date.new(1943 + i, 2, 22))
    end

    import!

    expect(HouseholdMember.find_by(name: "Bins, Froederick").member).to be_nil
  end

  it "replaces the people in a household rather than accumulating them" do
    import!
    import!

    household = unit.households.find_by(name: "Bins, Froederick & Lisette")
    expect(household.household_members.count).to eq(5)
    expect(Household.count).to eq(4)
  end

  it "finishes the job" do
    import!

    expect(import_job.reload).to be_finished
    expect(import_job.succeeded_count).to eq(4)
    expect(import_job.failed_count).to eq(0)
  end

  context "when the individuals list is imported afterwards" do
    let(:members_job) { unit.import_jobs.create!(status: :waiting, kind: :individuals) }

    before do
      members_job.raw_data.attach(io: file_fixture("raw_member_list.txt").open, filename: "raw_data.txt",
                                  content_type: "text/plain")
    end

    it "links up the people it could not match before" do
      import!
      expect(HouseholdMember.find_by(name: "Bins, Froederick").member).to be_nil

      described_class.perform!(members_job)

      expect(HouseholdMember.find_by(name: "Bins, Froederick").member).to be_present
    end
  end
end
