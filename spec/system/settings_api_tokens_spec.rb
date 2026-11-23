require "rails_helper"

describe "Manage personal API tokens" do
  context "when the user is assigned to a unit" do
    let(:user) { users(:sunny_bishopric) }

    before { login_as user, scope: :user }

    it "creates a token, shows it once, and revokes it" do
      visit settings_preferences_path
      click_link "API Tokens"
      expect(page).to have_current_path(settings_api_tokens_path)
      expect(page).to have_text("You have no API tokens.")

      fill_in "Name", with: "Claude Code"
      select "30 days", from: "Expires after"
      click_button "Create Token"
      expect(page).to have_text("reviewed the General Handbook's guidance")
      expect(page).to have_no_css("#created_api_token")

      check "api_token_guidance_acknowledged"
      click_button "Create Token"

      plaintext = find_by_id("created_api_token").find("code").text
      expect(plaintext).to start_with("edify_")
      expect(::ApiToken.authenticate(plaintext)).to eq(user.api_tokens.sole)
      within("#api_tokens") { expect(page).to have_text("Claude Code").and have_text("Read only") }

      visit settings_api_tokens_path
      expect(page).to have_no_css("#created_api_token")
      expect(page).to have_no_text(plaintext)

      click_button "Revoke"
      expect(page).to have_text("Revoked \"Claude Code\".")
      within("#api_tokens") { expect(page).to have_text("Revoked").and have_no_button("Revoke") }
      expect(::ApiToken.authenticate(plaintext)).to be_nil
    end
  end

  context "when the user is not assigned to a unit" do
    before { login_as users(:unassigned), scope: :user }

    it "does not offer API tokens in the settings sidebar" do
      visit settings_preferences_path
      expect(page).to have_link("Password")
      expect(page).to have_no_link("API Tokens")
    end
  end
end
