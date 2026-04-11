require "rails_helper"

RSpec.describe NewUserAdminNotification do
  let(:user) { users(:sunny_bishopric) }
  let(:admin) { users(:admin) }

  it "creates an event and notification" do
    expect do
      described_class.with(user: user).deliver(admin)
    end.to change(Noticed::Event, :count).by(1)
                                         .and change(Noticed::Notification, :count).by(1)
  end

  describe "notification methods" do
    before { described_class.with(user: user).deliver(admin) }

    let(:notification) { Noticed::Notification.last }

    it "returns the correct message" do
      expect(notification.message).to be_present
    end

    it "returns the correct subject" do
      expect(notification.subject).to be_present
    end

    it "returns the user" do
      expect(notification.user).to eq(user)
    end
  end
end
