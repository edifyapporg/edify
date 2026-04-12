require "rails_helper"

RSpec.describe NotificationsController, type: :controller do
  include Devise::Test::ControllerHelpers

  let(:user) { users(:sunny_bishopric) }

  before { sign_in user }

  describe "GET #index" do
    before do
      NewUserNotification.with(user: user).deliver(user)
    end

    it "returns a successful response" do
      get :index
      expect(response).to be_successful
    end

    it "marks unread notifications as read" do
      expect(user.notifications.unread.count).to eq(1)
      get :index
      expect(user.notifications.unread.count).to eq(0)
    end
  end
end
