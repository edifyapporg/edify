require "rails_helper"

RSpec.describe IncompleteMeetingNotification do
  let(:unit) { units(:sunny_hills) }
  let(:recipient) { users(:sunny_bishopric) }
  let(:meeting) { unit.meetings.first }

  it "creates an event and notification" do
    expect do
      described_class.with(meeting: meeting).deliver(recipient)
    end.to change(Noticed::Event, :count).by(1)
                                         .and change(Noticed::Notification, :count).by(1)
  end

  describe "notification methods" do
    before { described_class.with(meeting: meeting).deliver(recipient) }

    let(:notification) { Noticed::Notification.last }

    it "returns the correct message" do
      expect(notification.message).to be_present
    end

    it "returns the correct subject" do
      expect(notification.subject).to be_present
    end

    it "returns the correct url" do
      expect(notification.url).to include("/meetings/")
    end
  end
end
