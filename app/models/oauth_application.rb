# An OAuth client, such as Claude, that a leader can authorize to read Edify through the MCP endpoint (#323). Clients
# are never registered by hand or through dynamic client registration: each is created from its Client ID Metadata
# Document the first time its URL arrives as a client_id at the signed-in authorization step
# (Oauth::AuthorizationsController, Oauth::ClientIdMetadataDocument). Doorkeeper's own lookups, including at the
# public token and revoke endpoints, only find clients already resolved there.
class OauthApplication < Doorkeeper::Application
  LOOPBACK_HOSTS = %w[localhost 127.0.0.1 [::1]].freeze

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
