require "rails_helper"

describe ::User do
  subject { described_class.new(phone_number: phone_number) }

  let(:phone_number) { "303-303-0303" }

  describe "callbacks" do
    it "defaults email notifications to true" do
      subject.valid?
      expect(subject.notification_preference_email).to eq(true)
    end

    context "when phone number is present" do
      it "defaults sms notifications to true" do
        subject.valid?
        expect(subject.notification_preference_sms).to eq(true)
      end
    end

    context "when phone number is not present" do
      let(:phone_number) { nil }
      it "defaults sms notifications to false" do
        subject.valid?
        expect(subject.notification_preference_sms).to eq(false)
      end
    end
  end

  describe "admin?" do
    let(:result) { user.admin? }

    context "when the user is an admin" do
      let(:user) { users(:admin) }
      it "returns true" do
        expect(result).to eq(true)
      end
    end

    context "when the user is not an admin" do
      let(:user) { users(:sunny_bishopric) }
      it "returns false" do
        expect(result).to eq(false)
      end
    end
  end

  describe "#send_welcome_notifications" do
    let(:user) do
      described_class.create!(
        first_name: "Test",
        last_name: "User",
        email: "testwelcome@example.com",
        password: "password123",
      )
    end

    it "sends welcome notifications when a user confirms their account" do
      expect do
        user.confirm
      end.to change(Noticed::Event, :count).by(2)

      event_types = Noticed::Event.last(2).map(&:type)
      expect(event_types).to contain_exactly("NewUserAdminNotification", "NewUserNotification")
    end

    it "delivers admin notification to all admin users" do
      admin_count = described_class.admin.count
      user.confirm

      admin_event = Noticed::Event.find_by(type: "NewUserAdminNotification")
      expect(admin_event.notifications.count).to eq(admin_count)
    end

    it "delivers new user notification to the user themselves" do
      user.confirm

      user_event = Noticed::Event.find_by(type: "NewUserNotification")
      expect(user_event.notifications.first.recipient).to eq(user)
    end
  end
end
