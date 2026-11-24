require "rails_helper"

RSpec.describe "Rate limits on sign-in, password reset and confirmation" do
  let(:user) { users(:sunny_bishopric) }
  let(:alert) { "Too many attempts. Wait a few minutes and try again." }
  # The test environment's cache is a null store, which never counts, so the limits count in a real one here.
  let(:store) { ActiveSupport::Cache::MemoryStore.new }

  before do
    allow(Rails.cache).to receive(:increment) { |*args, **options| store.increment(*args, **options) }
  end

  def sign_in(email: user.email, password: "wrong", ip: "203.0.113.1")
    post user_session_path, params: { user: { email: email, password: password } }, env: { "REMOTE_ADDR" => ip }
  end

  describe "signing in" do
    it "lets a leader sign in normally" do
      sign_in(password: "password")

      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to be_nil
    end

    it "refuses an email address after 10 attempts in 10 minutes, even with the right password" do
      10.times { |i| sign_in(ip: "203.0.113.#{i + 1}") }
      sign_in(password: "password", ip: "198.51.100.1")

      expect(response).to redirect_to(new_user_session_path)
      expect(response).to have_http_status(:see_other)
      expect(flash[:alert]).to eq(alert)
      expect(controller.current_user).to be_nil
    end

    it "refuses an IP after 20 attempts in 10 minutes, across email addresses" do
      20.times { |i| sign_in(email: "guess#{i}@example.com") }
      sign_in(password: "password")

      expect(flash[:alert]).to eq(alert)
      expect(controller.current_user).to be_nil
    end

    it "counts an email address however it's capitalized or spaced" do
      10.times { |i| sign_in(email: i.even? ? " #{user.email.upcase} " : user.email, ip: "203.0.113.#{i + 1}") }
      sign_in(ip: "198.51.100.1")

      expect(flash[:alert]).to eq(alert)
    end

    it "lets the leader sign in again once the window passes" do
      10.times { |i| sign_in(ip: "203.0.113.#{i + 1}") }

      travel(11.minutes) { sign_in(password: "password", ip: "198.51.100.1") }

      expect(response).to redirect_to(root_path)
    end
  end

  describe "requesting a password reset" do
    def request_reset(ip: "203.0.113.1")
      post user_password_path, params: { user: { email: user.email } }, env: { "REMOTE_ADDR" => ip }
    end

    it "sends at most 3 reset emails to one address in 15 minutes" do
      expect { 4.times { |i| request_reset(ip: "203.0.113.#{i + 1}") } }
        .to change { ActionMailer::Base.deliveries.count }.by(3)
      expect(response).to redirect_to(new_user_password_path)
      expect(flash[:alert]).to eq(alert)
    end
  end

  describe "resending confirmation instructions" do
    def resend(ip: "203.0.113.1")
      post user_confirmation_path, params: { user: { email: "someone@example.com" } }, env: { "REMOTE_ADDR" => ip }
    end

    it "refuses after 3 requests for one address in 15 minutes" do
      4.times { |i| resend(ip: "203.0.113.#{i + 1}") }

      expect(response).to redirect_to(new_user_confirmation_path)
      expect(flash[:alert]).to eq(alert)
    end
  end
end
