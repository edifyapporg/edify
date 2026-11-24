require "rails_helper"

RSpec.describe "Settings connected apps" do
  let(:user) { users(:sunny_bishopric) }
  let(:other_user) { users(:admin) }
  let(:claude) do
    ::OauthApplication.create!(name: "Claude", uid: "https://claude.ai/oauth/mcp-client-metadata", confidential: false,
                               redirect_uri: "https://claude.ai/api/mcp/auth_callback", scopes: "read",
                               metadata_fetched_at: Time.current)
  end

  def issue_token(owner, application: claude)
    ::OauthAccessToken.create!(application: application, resource_owner_id: owner.id, scopes: "read",
                               expires_in: 1.hour.to_i, use_refresh_token: true)
  end

  describe "GET /settings/connected_apps" do
    before { login_as user, scope: :user }

    it "lists the apps the user has connected, with where they're from" do
      issue_token(user)
      get settings_connected_apps_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Claude", "claude.ai", ">Disconnect<")
    end

    it "shows a leader with MCP access how to connect Claude, with this host's MCP URL" do
      user.update!(admin: true)
      get settings_connected_apps_path

      expect(response.body).to include("Connect Claude", "http://www.example.com/mcp",
                                       "claude mcp add --transport http edify http://www.example.com/mcp",
                                       %(href="#{::EdifyConfig.general_handbook_url}"), "Help improve Claude")
    end

    it "leaves out the guide for a leader MCP isn't enabled for, while still listing their apps" do
      issue_token(user)
      get settings_connected_apps_path

      expect(response.body).not_to include("Connect Claude")
      expect(response.body).to include("Claude", ">Disconnect<")
    end

    it "says so when there are none, and never shows another user's connections" do
      issue_token(other_user)
      get settings_connected_apps_path

      expect(response.body).to include("You haven't connected any apps.")
    end

    it "leaves out an app whose access has been revoked or went unused for 30 days" do
      issue_token(user).revoke
      travel(-31.days) { issue_token(user) }

      get settings_connected_apps_path
      expect(response.body).to include("You haven't connected any apps.")
    end
  end

  describe "DELETE /settings/connected_apps/:id" do
    before { login_as user, scope: :user }

    it "revokes the app's tokens and codes for this user only, cutting off its MCP access at once" do
      token = issue_token(user)
      other_token = issue_token(other_user)
      grant = ::Doorkeeper::AccessGrant.create!(application: claude, resource_owner_id: user.id, expires_in: 600,
                                                redirect_uri: claude.redirect_uri, scopes: "read")

      delete settings_connected_app_path(claude)

      expect(response).to redirect_to(settings_connected_apps_path)
      expect(flash[:notice]).to eq("Disconnected Claude.")
      expect([token.reload, grant.reload]).to all(be_revoked)
      expect(other_token.reload).not_to be_revoked
    end

    it "means the next MCP request with that token is refused" do
      user.update!(admin: true)
      token = issue_token(user)
      delete settings_connected_app_path(claude)

      host! "localhost"
      post "/mcp", params: { jsonrpc: "2.0", id: 1, method: "tools/list" }.to_json,
                   headers: { "Authorization" => "Bearer #{token.plaintext_token}", "Content-Type" => "application/json",
                              "Accept" => "application/json, text/event-stream" }

      expect(response).to have_http_status(:unauthorized)
    end

    it "cannot find an app the user hasn't connected, and leaves other users' access alone" do
      other_token = issue_token(other_user)

      expect { delete settings_connected_app_path(claude) }.to raise_error(ActiveRecord::RecordNotFound)
      expect(other_token.reload).not_to be_revoked
    end
  end

  context "when signed out" do
    it "sends the visitor to sign in" do
      get settings_connected_apps_path
      expect(response).to redirect_to(new_user_session_path)
    end
  end
end
