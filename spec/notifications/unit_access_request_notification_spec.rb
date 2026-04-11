require "rails_helper"

RSpec.describe UnitAccessRequestNotification do
  let(:user) { users(:sunny_bishopric) }
  let(:recipient) { users(:sunny_bishopric) }

  it "creates an event and notification" do
    expect do
      described_class.with(user: user).deliver(recipient)
    end.to change(Noticed::Event, :count).by(1)
                                         .and change(Noticed::Notification, :count).by(1)
  end

  describe "notification methods" do
    before { described_class.with(user: user).deliver(recipient) }

    let(:notification) { Noticed::Notification.last }

    it "returns the correct message" do
      expect(notification.message).to include(user.name)
    end

    it "returns the correct subject" do
      expect(notification.subject).to be_present
    end

    it "returns the correct url" do
      expect(notification.url).to include("/users")
    end
  end
end
