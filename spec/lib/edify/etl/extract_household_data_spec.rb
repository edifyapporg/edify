require "rails_helper"
require "edify/etl"

describe ::Edify::Etl::ExtractHouseholdData do
  subject { described_class.new(import_job) }

  let(:unit) { units(:sunny_hills) }
  let(:import_job) { unit.import_jobs.create!(status: :waiting, kind: :households) }
  let(:result) { subject.perform }

  before do
    import_job.raw_data.attach(io: file_fixture(raw_data_file_name).open, filename: "raw_data.txt",
                               content_type: "text/plain")
  end

  context "when the household list is valid" do
    let(:raw_data_file_name) { "raw_household_list.txt" }

    it "returns one household per record" do
      expect(result.count).to eq(4)
      expect(result).to all be_a(::Edify::Etl::RawHousehold)
      expect(import_job.errors).to be_empty
    end

    it "reads the household's name, address and shared contact details" do
      household = result.first

      expect(household.name).to eq("Bins, Froederick & Lisette")
      expect(household.address_lines).to eq(["1433 N 1500 E", "Provo UT 84604-3712"])
      expect(household.phone_number).to eq("(801) 545-4545")
      expect(household.email).to eq("froederick@frank.com")
    end

    it "gives every person the household's surname unless they carry their own" do
      expect(result.first.people.map(&:name))
        .to eq(["Bins, Froederick", "Bins, Lisette", "Bins, Steve", "Bins, Hildy", "Bins, Wanda"])
      expect(result.second.people.map(&:name)).to eq(["Cummerata, Wilma", "Heidenrick, Kenneth"])
    end

    it "keeps a person whose name begins with a street abbreviation" do
      # "Ste" is the abbreviation for a suite, and "Steve" must not be read as part of the address.
      expect(result.first.people.map(&:name)).to include("Bins, Steve")
    end

    it "records the ages the directory lists, and only those" do
      hildy, wanda = result.first.people.last(2)

      expect(hildy.listed_age).to eq(14)
      expect(wanda.listed_age).to eq(7)
      expect(result.first.people.first.listed_age).to be_nil
    end

    it "marks the adults the household is named for as its parents" do
      expect(result.first.people.select(&:parent).map(&:name)).to eq(["Bins, Froederick", "Bins, Lisette"])
      expect(result.second.people.select(&:parent).map(&:name)).to eq(["Cummerata, Wilma"])
    end

    it "drops status notes the directory puts on their own line" do
      expect(result.second.people.map(&:name)).not_to include("Out-of-Unit")
    end

    it "keeps a secondary address line" do
      expect(result.second.address_lines).to eq(["255 S University Ave", "Apt B401", "Provo UT 84601-4593"])
    end

    it "leaves the email blank when the directory has only a phone number" do
      expect(result.second.phone_number).to eq("(801) 232-3232")
      expect(result.second.email).to be_nil
    end

    it "reads a household the directory has no contact details for" do
      # A ZIP+4 reads as a phone number, so the address has to be recognised first.
      expect(result.third.name).to eq("Bode, Yolanda")
      expect(result.third.address_lines).to eq(["1105 Terrace Dr", "Provo UT 84604-3753"])
      expect(result.third.phone_number).to be_nil
      expect(result.third.people.map(&:name)).to eq(["Bode, Yolanda"])
    end

    it "reads a household whose whole address is a state" do
      expect(result.fourth.address_lines).to eq(["Utah"])
      expect(result.fourth.people.map(&:name)).to eq(["Stelling, Marta"])
    end
  end

  context "when the individuals list is pasted by mistake" do
    let(:raw_data_file_name) { "raw_member_list.txt" }

    it "says which tab to copy instead of failing obscurely" do
      result

      expect(import_job.errors.full_messages.join).to include("Households tab")
    end
  end
end
