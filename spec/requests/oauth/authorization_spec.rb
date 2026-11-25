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
        "scopes_supported" => %w[read offline_access],
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
      expect(response.body).to include("If someone sent\n          you this link, choose Deny")
      expect(response.body).not_to include("finishes on your own computer")
    end

    it "submits Allow and Deny as ordinary forms, so the browser follows the redirect to the client itself" do
      login_as user, scope: :user
      get oauth_authorization_path, params: authorize_params

      forms = response.parsed_body.css("form[action=\"/oauth/authorize\"]")
      expect(forms.size).to eq(2)
      expect(forms.pluck("data-turbo")).to all(eq("false"))
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
      expect(response.body).to include("This connection can&#39;t be made")
    end

    it "never fetches a client_id from an untrusted host" do
      login_as user, scope: :user
      get oauth_authorization_path, params: authorize_params(client_id: "https://evil.example/client.json")

      expect(response.body).not_to include("Connect")
      expect(::Oauth::ClientIdMetadataDocument::Fetcher).not_to have_received(:call)
    end

    it "refuses an admin who is impersonating the leader, before fetching anything" do
      admin = users(:admin)
      login_as admin, scope: :user
      post impersonate_start_path(user)

      get oauth_authorization_path, params: authorize_params

      expect(response).to have_http_status(:forbidden)
      expect(response.body).to include("Stop impersonating to connect an app")
      expect(::Oauth::ClientIdMetadataDocument::Fetcher).not_to have_received(:call)
    end

    it "refuses a user with no unit, whom the MCP endpoint wouldn't serve, so no token is issued" do
      login_as users(:unassigned), scope: :user
      get oauth_authorization_path, params: authorize_params

      expect(response).to have_http_status(:forbidden)
      expect(response.body).to include("Connecting apps needs a ward")

      post oauth_authorization_path, params: authorize_params
      expect(response).to have_http_status(:forbidden)
      expect(::Doorkeeper::AccessGrant.count).to eq(0)
    end

    it "answers a malformed resource with 400, not an error" do
      login_as user, scope: :user
      get oauth_authorization_path, params: authorize_params(resource: "//www.example.com/mcp")

      expect(response).to have_http_status(:bad_request)
    end

    it "emails the leader once they choose Allow, but not when they deny" do
      login_as user, scope: :user
      get oauth_authorization_path, params: authorize_params

      expect { delete oauth_authorization_path, params: authorize_params }
        .not_to have_enqueued_mail(::AccountSecurityMailer)
      expect { post oauth_authorization_path, params: authorize_params }
        .to have_enqueued_mail(::AccountSecurityMailer, :app_connected)
        .with(user, ::OauthApplication.find_by!(uid: client_id), loopback: false)
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

    context "with a client that lists both an https and a loopback redirect" do
      let(:redirect_uris) { ["https://claude.ai/api/mcp/auth_callback", "http://localhost/callback"] }

      it "warns only when this request's redirect is the loopback one" do
        login_as user, scope: :user
        get oauth_authorization_path, params: authorize_params
        expect(response.body).not_to include("finishes on your own computer")

        get oauth_authorization_path, params: authorize_params(redirect_uri: "http://localhost:5555/callback")
        expect(response.body).to include("finishes on your own computer")
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

    it "keeps the authorization code and PKCE verifier out of the request log" do
      log = StringIO.new
      original = ActionController::Base.logger
      ActionController::Base.logger = ActiveSupport::Logger.new(log)
      begin
        code = authorization_code
        exchange(code)
      ensure
        ActionController::Base.logger = original
      end

      expect(response).to have_http_status(:ok)
      expect(log.string).to include("Redirected to [FILTERED]")
      expect(log.string).not_to include(code, code_verifier)
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

    it "never fetches a client document at the public token endpoint" do
      post oauth_token_path, params: { grant_type: "authorization_code", code: "x", code_verifier: code_verifier,
                                       client_id: "https://claude.ai/oauth/never-seen", redirect_uri: redirect_uri }

      expect(response.parsed_body["error"]).to eq("invalid_client")
      expect(::Oauth::ClientIdMetadataDocument::Fetcher).not_to have_received(:call)
    end

    it "refuses the exchange for another resource" do
      exchange(authorization_code, resource: "https://elsewhere.example/mcp")

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body["error"]).to eq("invalid_target")
    end

    it "sends no email for the code exchange or a refresh" do
      code = authorization_code

      expect do
        exchange(code)
        refresh(response.parsed_body.fetch("refresh_token"))
      end.not_to have_enqueued_mail(::AccountSecurityMailer)
      expect(response).to have_http_status(:ok)
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

  describe "ChatGPT" do
    # ChatGPT's real document, as served at its client_id URL. It prefers private_key_jwt but also supports none,
    # which is all Edify advertises.
    let(:client_id) { "https://chatgpt.com/oauth/client.json" }
    let(:redirect_uri) { "https://chatgpt.com/connector_platform_oauth_redirect" }

    before do
      allow(::Oauth::ClientIdMetadataDocument::Fetcher).to receive(:call) do
        { client_id: client_id, client_uri: "https://chatgpt.com/", redirect_uris: [redirect_uri],
          token_endpoint_auth_method: "private_key_jwt", token_endpoint_auth_methods_supported: %w[none private_key_jwt],
          grant_types: %w[authorization_code refresh_token urn:ietf:params:oauth:grant-type:jwt-bearer],
          response_types: ["code"], client_name: "ChatGPT", token_endpoint_auth_signing_alg: "RS256",
          jwks_uri: "https://chatgpt.com/oauth/jwks.json" }.to_json
      end
    end

    it "asks for consent, listing read access even when ChatGPT asks only for offline_access" do
      login_as user, scope: :user
      get oauth_authorization_path, params: authorize_params(scope: "offline_access")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("ChatGPT", "chatgpt.com", "See your unit&#39;s members",
                                       "Stay connected until you disconnect it")
    end

    it "issues tokens for read and offline_access, and refreshes them" do
      exchange(authorization_code(scope: "read offline_access"))
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include("scope" => "read offline_access")

      refresh(response.parsed_body.fetch("refresh_token"))
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.fetch("access_token")).to be_present
    end
  end

  describe "log filtering" do
    let(:filter) { ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters) }

    it "filters OAuth codes and PKCE verifiers, but not other names containing code" do
      filtered = filter.filter("code" => "abc", "code_verifier" => "def", "zip_code" => "84101", "code_challenge" => "x")

      expect(filtered).to eq("code" => "[FILTERED]", "code_verifier" => "[FILTERED]", "zip_code" => "84101",
                             "code_challenge" => "x")
    end

    it "filters only redirects that carry an authorization code" do
      patterns = Rails.application.config.filter_redirect

      expect(patterns).to(be_any { |pattern| pattern.match?("https://claude.ai/api/mcp/auth_callback?code=a&state=s") })
      expect(patterns).not_to(be_any { |pattern| pattern.match?("https://www.edifyapp.org/meetings?zip_code=1") })
    end
  end
end
