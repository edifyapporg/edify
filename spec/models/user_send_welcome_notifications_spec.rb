require "rails_helper"

RSpec.describe User, "#send_welcome_notifications" do
  let(:user) do
    described_class.create!(
      first_name: "Test",
      last_name: "User",
      email: "testwelcome@example.com",
      password: "password123"
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
