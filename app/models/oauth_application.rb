# An OAuth client, such as Claude, that a leader can authorize to read Edify through the MCP endpoint (#323). Clients
# are never registered by hand or through dynamic client registration: each is created from its Client ID Metadata
# Document the first time its URL arrives as a client_id at the signed-in authorization step
# (Oauth::AuthorizationsController, Oauth::ClientIdMetadataDocument). Doorkeeper's own lookups, including at the
# public token and revoke endpoints, only find clients already resolved there.
class OauthApplication < Doorkeeper::Application
  LOOPBACK_HOSTS = %w[localhost 127.0.0.1 [::1]].freeze

  # Clients the user can still reach Edify through: those with an unrevoked token young enough that its access token
  # is live or its refresh token still works. Shown on Settings > Connected Apps.
  # @param user [User]
  # @return [ActiveRecord::Relation<OauthApplication>]
  def self.connected_for(user)
    tokens = ::OauthAccessToken.where(resource_owner_id: user.id, revoked_at: nil)
                               .where(created_at: ::OauthAccessToken::REFRESH_TOKEN_LIFETIME.ago..)
    where(id: tokens.select(:application_id))
  end

  # @return [String] the host of the client's metadata document, e.g. "claude.ai"
  def client_host
    ::URI.parse(uid).host
  rescue ::URI::InvalidURIError
    uid
  end

  # @param user [User]
  # @return [Time, nil] when the user last signed in through this client or it last refreshed their access
  def last_authorized_at(user)
    access_tokens.where(resource_owner_id: user.id).maximum(:created_at)
  end

  # @param uri [URI::Generic]
  # @return [Boolean] true for a plain-http redirect to this machine, as native clients such as Claude Code use
  def self.loopback_redirect?(uri)
    uri.scheme == "http" && LOOPBACK_HOSTS.include?(uri.host)
  end

  # @return [Array<String>]
  def redirect_uris
    redirect_uri.to_s.split
  end
end
