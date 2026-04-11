require "rails_helper"

RSpec.describe Analytics::EmailEvent do
  describe "validations" do
    it { expect(described_class.new(email: "a@b.com", event: "delivered", timestamp: Time.current)).to be_valid }
    it { expect(described_class.new(email: nil, event: "delivered", timestamp: Time.current)).not_to be_valid }
    it { expect(described_class.new(email: "a@b.com", event: nil, timestamp: Time.current)).not_to be_valid }
    it { expect(described_class.new(email: "a@b.com", event: "delivered", timestamp: nil)).not_to be_valid }
  end

  describe "#timestamp=" do
    it "converts a numeric Unix timestamp to a Time" do
      event = described_class.new(timestamp: 1_683_409_840)
      expect(event.timestamp).to eq(Time.zone.at(1_683_409_840))
    end

    it "converts a numeric string to a Time" do
      event = described_class.new(timestamp: "1683409840")
      expect(event.timestamp).to eq(Time.zone.at(1_683_409_840))
    end

    it "passes through a Time object unchanged" do
      time = Time.zone.now
      event = described_class.new(timestamp: time)
      expect(event.timestamp).to be_within(1.second).of(time)
    end
  end
end
