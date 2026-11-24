require "rails_helper"

RSpec.describe "MCP endpoint with OAuth" do
  let(:user) { users(:sunny_bishopric) }
  let(:application) do
    ::OauthApplication.create!(name: "Claude", uid: "https://claude.ai/oauth/mcp-client-metadata", confidential: false,
                               redirect_uri: "https://claude.ai/api/mcp/auth_callback", scopes: "read",
                               metadata_fetched_at: Time.current)
  end
  let(:oauth_token) do
    ::OauthAccessToken.create!(application: application, resource_owner_id: user.id, scopes: "read",
                               expires_in: 1.hour.to_i, use_refresh_token: true)
  end
  let(:bearer) { { "Authorization" => "Bearer #{oauth_token.plaintext_token}" } }

  # Admins may use MCP until it is enabled for everyone. The transport's DNS-rebinding check allows loopback hosts.
  before do
    user.update!(admin: true)
    host! "localhost"
  end

  def rpc(method, params = {}, headers: bearer)
    post "/mcp", params: { jsonrpc: "2.0", id: 1, method: method, params: params }.to_json,
                 headers: { "Content-Type" => "application/json", "Accept" => "application/json, text/event-stream",
                            "MCP-Protocol-Version" => "2025-11-25" }.merge(headers)
  end

  describe "discovery" do
    it "answers a request without a token with 401 pointing at the protected resource metadata, with the scope" do
      rpc("tools/list", headers: {})

      expect(response).to have_http_status(:unauthorized)
      challenge = response.headers["WWW-Authenticate"]
      expect(challenge).to include('resource_metadata="http://localhost/.well-known/oauth-protected-resource/mcp"')
      expect(challenge).to include('scope="read"')
    end

    it "serves the protected resource metadata at the path-inserted and root well-known URLs" do
      [mcp_protected_resource_metadata_path, "/.well-known/oauth-protected-resource"].each do |path|
        get path

        expect(response.parsed_body).to eq(
          "resource" => "http://localhost/mcp",
          "authorization_servers" => ["http://localhost"],
          "scopes_supported" => ["read"],
          "bearer_methods_supported" => ["header"],
          "resource_name" => "Edify"
        )
      end
    end

    it "names the authorization server whose metadata issuer matches" do
      get mcp_protected_resource_metadata_path
      issuer = response.parsed_body.fetch("authorization_servers").first

      get oauth_authorization_server_metadata_path
      expect(response.parsed_body.fetch("issuer")).to eq(issuer)
    end
  end

  describe "an OAuth access token" do
    it "lists the tools and answers for the leader's own unit" do
      rpc("tools/list")
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("result", "tools").pluck("name")).to include("list_stale_speakers")

      rpc("tools/call", { name: "search_members", arguments: { query: "bartell" } })
      members = response.parsed_body.dig("result", "structuredContent", "members")
      expect(members.pluck("name")).to eq(["Bartell, Randal"])
    end

    it "is refused once expired" do
      bearer
      travel(61.minutes) { rpc("tools/list") }

      expect(response).to have_http_status(:unauthorized)
      expect(response.headers["WWW-Authenticate"]).to include("invalid_token")
    end

    it "is refused once revoked" do
      oauth_token.revoke
      rpc("tools/list")

      expect(response).to have_http_status(:unauthorized)
    end

    it "is refused for a leader MCP isn't enabled for yet" do
      user.update!(admin: false)
      rpc("tools/list")

      expect(response).to have_http_status(:unauthorized)
      expect(response.headers["WWW-Authenticate"]).to include("not enabled for your account yet")
    end

    it "revokes the refresh token it replaced, once it is first used" do
      previous = ::OauthAccessToken.create!(application: application, resource_owner_id: user.id, scopes: "read",
                                            expires_in: 1.hour.to_i, use_refresh_token: true)
      oauth_token.update!(previous_refresh_token: previous.refresh_token)

      rpc("tools/list")

      expect(previous.reload).to be_revoked
    end

    it "is refused for a random string that is neither kind of token" do
      rpc("tools/list", headers: { "Authorization" => "Bearer not-a-token" })
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
