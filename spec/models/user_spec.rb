require "rails_helper"

describe ::User do
  subject { described_class.new(phone_number: phone_number) }

  let(:phone_number) { "303-303-0303" }

  describe "callbacks" do
    it "defaults email notifications to true" do
      subject.valid?
      expect(subject.notification_preference_email).to eq(true)
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

  describe "#otp_required_for_login" do
    it "is true only for an authenticator app" do
      required = described_class.two_factor_methods.keys.index_with do |method|
        described_class.new(two_factor_method: method).otp_required_for_login
      end

      expect(required).to eq("none" => false, "email" => false, "authenticator" => true)
    end
  end

  describe "#otp_secret" do
    it "is stored encrypted" do
      user = users(:sunny_bishopric)
      secret = described_class.generate_otp_secret
      user.update!(otp_secret: secret)

      stored = described_class.connection.select_value("SELECT otp_secret FROM users WHERE id = #{user.id}")
      expect(stored).not_to include(secret)
      expect(user.reload.otp_secret).to eq(secret)
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
