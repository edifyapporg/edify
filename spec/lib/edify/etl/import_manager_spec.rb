require "rails_helper"
require "edify/etl"

describe ::Edify::Etl::ImportManager do
  subject { described_class.new(import_job) }

  let(:unit) { units(:sunny_hills) }
  let(:import_job) { unit.import_jobs.create!(status: :waiting) }
  let(:raw_member_rows) do
    [
      ::Edify::Etl::RawMemberRow.new(:name => "Bins, Froederick", :gender => "M", :birthdate => "22 Feb 1943", :phone_number => "(801) 545-4545", :email => "froederick@frank.com"),
      ::Edify::Etl::RawMemberRow.new(:name => "Cummerata, Lisette", :gender => "F", :birthdate => "19 Sep 1979", :phone_number => "07710587623", :email => "lisette@cummerata.com"),
      ::Edify::Etl::RawMemberRow.new(:name => "Heidenrick, Kenneth", :gender => "M", :birthdate => "1 Jul 1963", :phone_number => "385-348-3585", :email => "heidenrick@kenneth.com"),
    ]
  end

  before { allow(::Edify::Etl::ExtractMemberData).to receive(:perform).and_return(raw_member_rows) }

  describe "#perform!" do
    context "when all member rows are valid" do
      it "saves members" do
        expect { subject.perform! }.to change(::Member, :count).by(3)
      end

      it "does not set an error message" do
        subject.perform!
        expect(import_job.error_message).to be_nil
      end

      it "sets import job attributes as expected" do
        subject.perform!
        expect(import_job.succeeded_count).to eq(3)
        expect(import_job.failed_count).to eq(0)
        expect(import_job.ignored_count).to eq(0)
        expect(import_job.status).to eq("finished")
      end
    end

    context "when a member row cannot be saved" do
      let(:raw_member_rows) do
        [
          ::Edify::Etl::RawMemberRow.new(:name => "Bins, Froederick", :gender => "M", :birthdate => "22 Feb 1943", :phone_number => "(801) 545-4545", :email => "froederick@frank.com"),
          ::Edify::Etl::RawMemberRow.new(:name => nil, :gender => "F", :birthdate => "19 Sep 1979", :phone_number => "07710587623", :email => "lisette@cummerata.com"),
          ::Edify::Etl::RawMemberRow.new(:name => "Heidenrick, Kenneth", :gender => "M", :birthdate => "1 Jul 1963", :phone_number => "385-348-3585", :email => "heidenrick@kenneth.com"),
        ]
      end

      it "saves the other members" do
        expect { subject.perform! }.to change(::Member, :count).by(2)
      end

      it "sets an error message" do
        subject.perform!
        expect(import_job.parsed_errors.count).to eq(1)
      end

      it "sets import job attributes as expected" do
        subject.perform!
        expect(import_job.succeeded_count).to eq(2)
        expect(import_job.failed_count).to eq(1)
        expect(import_job.ignored_count).to eq(0)
        expect(import_job.status).to eq("failed")
      end
    end

    context "when no member rows are extracted" do
      let(:raw_member_rows) { [] }

      it "does not save any members" do
        expect { subject.perform! }.not_to change(::Member, :count)
      end

      it "does not set any error message" do
        subject.perform!
        expect(import_job.error_message).to be_nil
      end

      it "sets import job attributes as expected" do
        subject.perform!
        expect(import_job.succeeded_count).to eq(0)
        expect(import_job.failed_count).to eq(0)
        expect(import_job.ignored_count).to eq(0)
        expect(import_job.status).to eq("finished")
      end
    end

    context "when the import job has errors" do
      before { import_job.errors.add(:base, "Extraction error at row 2") }

      it "does not attempt to save members" do
        expect { subject.perform! }.not_to change(::Member, :count)
      end

      it "sets the error message on the import job" do
        subject.perform!
        expect(import_job.parsed_errors).to eq(["Extraction error at row 2"])
      end

      it "sets import job attributes as expected" do
        subject.perform!
        expect(import_job.succeeded_count).to eq(0)
        expect(import_job.failed_count).to eq(0)
        expect(import_job.ignored_count).to eq(0)
        expect(import_job.status).to eq("failed")
      end
    end
  end

  describe "the age a member has to reach to be stored" do
    let(:raw_member_rows) do
      [
        ::Edify::Etl::RawMemberRow.new(name: "Unbaptized, Eight", gender: "M",
                                       birthdate: Member::MINIMUM_SPEAKER_AGE.years.ago.to_date.to_s),
        ::Edify::Etl::RawMemberRow.new(name: "Toddler, Tiny", gender: "F", birthdate: 3.years.ago.to_date.to_s),
      ]
    end

    it "keeps a child who has reached the minimum age, baptized or not" do
      expect { subject.perform! }.to change(::Member, :count).by(1)

      child = unit.members.find_by(name: "Unbaptized, Eight")
      expect(child.age).to eq(Member::MINIMUM_SPEAKER_AGE)
      expect(child.speaker_category).to eq(:child)
    end

    it "still ignores anyone younger" do
      subject.perform!

      expect(unit.members.find_by(name: "Toddler, Tiny")).to be_nil
      expect(import_job.reload.ignored_count).to eq(1)
    end
  end
end
