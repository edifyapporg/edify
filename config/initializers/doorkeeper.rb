# Doorkeeper makes Edify an OAuth authorization server, so Claude can connect to the MCP endpoint with a leader's
# own sign-in instead of a pasted personal access token (#323). Only the authorization code flow with S256 PKCE is
# enabled. Claude identifies itself with a Client ID Metadata Document, which OauthApplication.by_uid resolves; there
# is no dynamic client registration. See docs/api.md.
Doorkeeper.configure do
  orm :active_record

  # Signed-out leaders go through the Devise sign-in, which returns them here afterwards.
  resource_owner_authenticator do
    current_user || warden.authenticate!(scope: :user)
  end

  base_controller "ApplicationController"

  application_class "OauthApplication"
  access_token_class "OauthAccessToken"

  grant_flows %w[authorization_code]
  force_pkce
  pkce_code_challenge_methods %w[S256]

  access_token_expires_in 1.hour
  # Each refresh issues a new refresh token and revokes the old one once the new access token is used. Refresh
  # tokens stop working after 30 days without use (OauthAccessToken::REFRESH_TOKEN_LIFETIME).
  use_refresh_token

  # Grants and tokens are stored as SHA-256 digests, like personal access tokens.
  hash_token_secrets

  default_scopes :read
  enforce_configured_scopes

  # Nothing introspects tokens: the MCP endpoint looks them up directly.
  allow_token_introspection false

  # Claude Code's redirect is plain http on a loopback address, which RFC 8252 allows. Everything else must be https.
  force_ssl_in_redirect_uri { |uri| !OauthApplication.loopback_redirect?(uri) }
end

# RFC 8252 lets a native client pick any port on a loopback redirect. Doorkeeper ignores the port only for loopback IP
# addresses, but Claude Code registers http://localhost/callback as well as http://127.0.0.1/callback, so "localhost"
# counts as loopback here too.
module LocalhostLoopbackRedirect
  def loopback_uri?(uri)
    super || uri.host == "localhost"
  end
end

Doorkeeper::OAuth::Helpers::URIChecker.singleton_class.prepend(LocalhostLoopbackRedirect)
