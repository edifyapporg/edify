require "rails_helper"

RSpec.describe ::Talk do
  let(:meeting) { units(:sunny_hills).meetings.create!(date: Date.new(2026, 11, 8), meeting_type: :sacrament_meeting) }
  let!(:jane) { meeting.talks.create!(speaker_name: "Smith, Jane", purpose: "Departing Missionary") }
  let!(:john) { meeting.talks.create!(speaker_name: "Smithson, John", purpose: "Stake Representative") }
  let!(:odd) { meeting.talks.create!(speaker_name: "Odd_Name 100%", purpose: nil) }

  def speakers(relation)
    relation.where(id: [jane, john, odd].map(&:id)).pluck(:speaker_name)
  end

  describe ".speaker_matching" do
    it "matches every word of the speaker's name, in any order, ignoring case" do
      expect(speakers(described_class.speaker_matching("jane SMITH"))).to eq(["Smith, Jane"])
      expect(speakers(described_class.speaker_matching("smith"))).to contain_exactly("Smith, Jane", "Smithson, John")
    end

    it "treats LIKE wildcards as plain characters" do
      expect(speakers(described_class.speaker_matching("_"))).to eq(["Odd_Name 100%"])
      expect(speakers(described_class.speaker_matching("%"))).to eq(["Odd_Name 100%"])
    end
  end

  describe ".purpose_containing" do
    it "matches part of the purpose, ignoring case" do
      expect(speakers(described_class.purpose_containing("missionary"))).to eq(["Smith, Jane"])
      expect(speakers(described_class.purpose_containing("  stake  "))).to eq(["Smithson, John"])
    end

    it "never matches a talk without a purpose" do
      expect(speakers(described_class.purpose_containing("a"))).not_to include("Odd_Name 100%")
    end
  end
end
