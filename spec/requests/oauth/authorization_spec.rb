require "rails_helper"

RSpec.describe "OAuth sign-in for MCP clients" do
  let(:user) { users(:sunny_bishopric) }
  let(:client_id) { "https://claude.ai/oauth/mcp-client-metadata" }
  let(:redirect_uri) { "https://claude.ai/api/mcp/auth_callback" }
  let(:redirect_uris) { [redirect_uri] }
  let(:resource) { "http://www.example.com/mcp" }
  let(:code_verifier) { ::SecureRandom.urlsafe_base64(48) }
  let(:code_challenge) { ::Base64.urlsafe_encode64(::Digest::SHA256.digest(code_verifier), padding: false) }

  before do
    allow(::Oauth::ClientIdMetadataDocument::Fetcher).to receive(:call) do
      { client_id: client_id, client_name: "Claude", redirect_uris: redirect_uris }.to_json
    end
  end

  def authorize_params(**overrides)
    { client_id: client_id, redirect_uri: redirect_uri, response_type: "code", state: "xyz",
      code_challenge: code_challenge, code_challenge_method: "S256", scope: "read", resource: resource, **overrides }
  end

  # Signs in, consents, and returns the authorization code from the redirect.
  def authorization_code(**overrides)
    login_as user, scope: :user
    post oauth_authorization_path, params: authorize_params(**overrides)
    expect(response).to have_http_status(:redirect)
    ::Rack::Utils.parse_query(::URI.parse(response.location).query).fetch("code")
  end

  def exchange(code, **overrides)
    post oauth_token_path, params: { grant_type: "authorization_code", code: code, client_id: client_id,
                                     redirect_uri: redirect_uri, code_verifier: code_verifier, resource: resource,
                                     **overrides }
  end

  def refresh(refresh_token)
    post oauth_token_path, params: { grant_type: "refresh_token", refresh_token: refresh_token, client_id: client_id,
                                     resource: resource }
  end

  describe "GET /.well-known/oauth-authorization-server" do
    it "describes the authorization server as MCP clients need" do
      get oauth_authorization_server_metadata_path

      expect(response.parsed_body).to include(
        "issuer" => "http://www.example.com",
        "authorization_endpoint" => "http://www.example.com/oauth/authorize",
        "token_endpoint" => "http://www.example.com/oauth/token",
        "code_challenge_methods_supported" => ["S256"],
        "token_endpoint_auth_methods_supported" => ["none"],
        "grant_types_supported" => %w[authorization_code refresh_token],
        "scopes_supported" => ["read"],
        "client_id_metadata_document_supported" => true
      )
      expect(response.parsed_body).not_to have_key("registration_endpoint")
    end
  end

  describe "GET /oauth/authorize" do
    it "sends a signed-out leader to sign in first" do
      get oauth_authorization_path, params: authorize_params
      expect(response).to redirect_to(new_user_session_path)
    end

    it "asks a signed-in leader to consent, naming the client and where they'll be sent" do
      login_as user, scope: :user
      get oauth_authorization_path, params: authorize_params

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Connect Claude to Edify?", "claude.ai", "It can&#39;t change anything")
      expect(response.body).not_to include("finishes on your own computer")
    end

    it "requires PKCE" do
      login_as user, scope: :user
      get oauth_authorization_path, params: authorize_params.except(:code_challenge, :code_challenge_method)

      expect(response.body).not_to include("Connect Claude to Edify?")
    end

    it "refuses a resource other than the MCP endpoint" do
      login_as user, scope: :user
      get oauth_authorization_path, params: authorize_params(resource: "https://elsewhere.example/mcp")

      expect(response).to have_http_status(:bad_request)
      expect(response.body).to include("This connection can't be made")
    end

    it "never fetches a client_id from an untrusted host" do
      login_as user, scope: :user
      get oauth_authorization_path, params: authorize_params(client_id: "https://evil.example/client.json")

      expect(response.body).not_to include("Connect")
      expect(::Oauth::ClientIdMetadataDocument::Fetcher).not_to have_received(:call)
    end

    context "with Claude Code's loopback redirect on a port it picked" do
      let(:redirect_uris) { ["http://localhost/callback", "http://127.0.0.1/callback"] }
      let(:redirect_uri) { "http://localhost:43117/callback" }

      it "accepts it and warns that the connection finishes on this computer" do
        login_as user, scope: :user
        get oauth_authorization_path, params: authorize_params

        expect(response.body).to include("Connect Claude to Edify?", "finishes on your own computer")
      end
    end
  end

  describe "the code exchange and refresh" do
    it "issues an hour-long access token and a refresh token for the signed-in leader" do
      exchange(authorization_code)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include("token_type" => "Bearer", "expires_in" => 3600, "scope" => "read")
      token = ::OauthAccessToken.by_token(response.parsed_body.fetch("access_token"))
      expect(token.resource_owner_id).to eq(user.id)
    end

    it "stores tokens only as digests" do
      exchange(authorization_code)
      plaintext = response.parsed_body.fetch("access_token")

      expect(::OauthAccessToken.where(token: plaintext)).to be_empty
    end

    it "refuses the exchange without the right code_verifier" do
      exchange(authorization_code, code_verifier: "wrong")
      expect(response.parsed_body["error"]).to eq("invalid_grant")
    end

    it "refuses the exchange for another resource" do
      exchange(authorization_code, resource: "https://elsewhere.example/mcp")

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body["error"]).to eq("invalid_target")
    end

    it "rotates the refresh token" do
      exchange(authorization_code)
      first_refresh = response.parsed_body.fetch("refresh_token")

      refresh(first_refresh)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.fetch("refresh_token")).not_to eq(first_refresh)
    end

    it "stops refreshing after 30 days without use" do
      exchange(authorization_code)
      refresh_token = response.parsed_body.fetch("refresh_token")

      travel(31.days) { refresh(refresh_token) }

      expect(response.parsed_body["error"]).to eq("invalid_grant")
    end
  end
end
