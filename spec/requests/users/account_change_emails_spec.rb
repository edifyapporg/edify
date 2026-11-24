require "rails_helper"

RSpec.describe "Account change emails" do
  let(:user) { users(:sunny_bishopric) }
  let(:new_password) { "a-new-password-123" }

  before { ActionMailer::Base.deliveries.clear }

  def deliveries_to(address)
    ActionMailer::Base.deliveries.select { |mail| mail.to.include?(address) }
  end

  describe "when the password changes" do
    it "emails the user after a change in settings" do
      login_as user, scope: :user
      put user_registration_path, params: { user: { current_password: "password", password: new_password,
                                                    password_confirmation: new_password } }

      mails = deliveries_to(user.email)
      expect(mails.map(&:subject)).to eq(["Password Changed"])
      expect(mails.first.body.encoded).to include("was just changed", "Reset your password", "Connected Apps")
    end

    it "emails the user after a reset" do
      raw_token = user.send(:set_reset_password_token)
      put user_password_path, params: { user: { reset_password_token: raw_token, password: new_password,
                                                password_confirmation: new_password } }

      expect(deliveries_to(user.email).map(&:subject)).to eq(["Password Changed"])
    end

    it "sends nothing when the current password is wrong" do
      login_as user, scope: :user
      put user_registration_path, params: { user: { current_password: "wrong", password: new_password,
                                                    password_confirmation: new_password } }

      expect(ActionMailer::Base.deliveries).to be_empty
    end
  end

  describe "when the email address changes" do
    let(:old_email) { user.email }

    def change_email
      old_email
      user.update!(email: "new-address@example.com")
    end

    it "emails the old address, pointing to the support address" do
      allow(::EdifyConfig).to receive(:support_email_address).and_return("help@example.com")
      change_email

      mails = deliveries_to(old_email)
      expect(mails.map(&:subject)).to eq(["Email Changed"])
      expect(mails.first.body.encoded).to include("new-address@example.com", "mailto:help@example.com")
      expect(deliveries_to("new-address@example.com")).to be_empty
    end

    it "points to the bishopric when no support address is set" do
      allow(::EdifyConfig).to receive(:support_email_address).and_return(nil)
      change_email

      expect(deliveries_to(old_email).first.body.encoded).to include("Ask your bishopric")
    end
  end

  it "sends nothing when other account details change" do
    user.update!(first_name: "Renamed")

    expect(ActionMailer::Base.deliveries).to be_empty
  end
end
