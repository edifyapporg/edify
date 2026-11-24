# An OAuth access token, with its refresh token, issued to a client a leader authorized (#323). Access tokens last an
# hour. Refresh tokens rotate on every refresh, so each one is a fresh record, and one left unused for
# REFRESH_TOKEN_LIFETIME no longer works: a leader who uses the connector at least monthly stays connected until they
# revoke it.
class OauthAccessToken < Doorkeeper::AccessToken
  REFRESH_TOKEN_LIFETIME = 30.days

  # Doorkeeper's lookup at the token endpoint's refresh grant. A refresh token past its lifetime is treated as
  # unknown, which Doorkeeper answers with invalid_grant, so the client signs the leader in again.
  # @param refresh_token [String]
  # @return [OauthAccessToken, nil]
  def self.by_refresh_token(refresh_token)
    token = super
    token if token && token.created_at > REFRESH_TOKEN_LIFETIME.ago
  end
end
