require "rails_helper"

RSpec.describe "Password changes" do
  let(:user) { users(:sunny_bishopric) }
  let(:new_password) { "a-new-password-123" }
  let(:claude) do
    ::OauthApplication.create!(name: "Claude", uid: "https://claude.ai/oauth/mcp-client-metadata", confidential: false,
                               redirect_uri: "https://claude.ai/api/mcp/auth_callback", scopes: "read",
                               metadata_fetched_at: Time.current)
  end
  let!(:oauth_token) do
    ::OauthAccessToken.create!(application: claude, resource_owner_id: user.id, scopes: "read",
                               expires_in: 1.hour.to_i, use_refresh_token: true)
  end
  let!(:grant) do
    ::Doorkeeper::AccessGrant.create!(application: claude, resource_owner_id: user.id, scopes: "read",
                                      expires_in: 10.minutes.to_i, redirect_uri: claude.redirect_uri,
                                      code_challenge: "challenge", code_challenge_method: "S256")
  end

  def refresh
    post oauth_token_path, params: { grant_type: "refresh_token", refresh_token: oauth_token.plaintext_refresh_token,
                                     client_id: claude.uid }
  end

  shared_examples "it ends OAuth access" do
    it "revokes the user's OAuth tokens and grants, so refreshing fails" do
      change_password

      expect(oauth_token.reload).to be_revoked
      expect(grant.reload).to be_revoked
      refresh
      expect(response.parsed_body["error"]).to eq("invalid_grant")
    end

    it "says the apps were disconnected and the API tokens still work" do
      api_token = user.api_tokens.create!(name: "CLI")
      change_password

      expect(flash[:notice]).to include("Apps you had connected to Edify, such as Claude, were disconnected.",
                                        "Your API token still works.")
      expect(api_token.reload.revoked_at).to be_nil
    end

    it "doesn't mention apps or API tokens the user doesn't have" do
      oauth_token.revoke
      change_password

      expect(flash[:notice]).not_to include("disconnected", "API token")
    end
  end

  describe "in settings" do
    def change_password(current_password: "password")
      login_as user, scope: :user
      put user_registration_path, params: { user: { current_password: current_password, password: new_password,
                                                    password_confirmation: new_password } }
    end

    it_behaves_like "it ends OAuth access"

    it "leaves OAuth access alone when the change fails" do
      change_password(current_password: "wrong")

      expect(oauth_token.reload).not_to be_revoked
    end
  end

  describe "through the reset email" do
    def change_password
      raw_token = user.send(:set_reset_password_token)
      put user_password_path, params: { user: { reset_password_token: raw_token, password: new_password,
                                                password_confirmation: new_password } }
    end

    it_behaves_like "it ends OAuth access"

    it "still shows Devise's reset form" do
      get edit_user_password_path(reset_password_token: user.send(:set_reset_password_token))

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("password_confirmation")
    end
  end

  it "leaves OAuth access alone when other account details change" do
    user.update!(first_name: "Renamed")

    expect(oauth_token.reload).not_to be_revoked
  end
end
