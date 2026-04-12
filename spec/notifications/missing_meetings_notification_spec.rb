require "rails_helper"

RSpec.describe MissingMeetingsNotification do
  let(:unit) { units(:sunny_hills) }
  let(:recipient) { users(:sunny_bishopric) }
  let(:dates) { [Date.new(2022, 5, 8), Date.new(2022, 5, 22)] }

  it "creates an event and notification" do
    expect do
      described_class.with(dates: dates).deliver(recipient)
    end.to change(Noticed::Event, :count).by(1)
                                         .and change(Noticed::Notification, :count).by(1)
  end

  describe "notification methods" do
    before { described_class.with(dates: dates).deliver(recipient) }

    let(:notification) { Noticed::Notification.last }

    it "returns the correct message" do
      expect(notification.message).to include("May 8")
      expect(notification.message).to include("May 22")
    end

    it "returns the correct subject" do
      expect(notification.subject).to be_present
    end

    it "returns the correct url" do
      expect(notification.url).to include("/meetings")
    end
  end
end
