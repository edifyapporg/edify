module EdifyMcp
  # Lets the MCP SDK's transport accept Edify personal access tokens (#317). The transport calls #verify on every
  # request and answers a rejection with 401 and a WWW-Authenticate challenge itself. The returned AccessToken reaches
  # tools as `server_context.auth_info`, with the user's id as its subject. OAuth tokens (#323) can be accepted here
  # later alongside these.
  class TokenVerifier < ::MCP::Server::OAuth::TokenVerifier
    InvalidToken = ::MCP::Server::OAuth::InvalidTokenError

    # @param token [String] the raw bearer token
    # @return [MCP::Server::OAuth::AccessToken]
    # @raise [MCP::Server::OAuth::InvalidTokenError] for an unknown, revoked or expired token, a user without a unit, or
    #   a user for whom MCP is not yet enabled. The messages reach the client in a header, so they carry no token data.
    def verify(token)
      api_token = ::ApiToken.authenticate(token)
      raise InvalidToken, "The API token is invalid, revoked or expired." unless api_token

      user = api_token.user
      raise InvalidToken, "Your Edify account is not assigned to a unit." unless user.assigned_to_unit?
      raise InvalidToken, "Edify's MCP server is not enabled for your account yet." unless Access.allowed?(user)

      api_token.touch_last_used!
      access_token_for(api_token)
    end

    private

    # Identifies the token by record id rather than carrying the secret any further.
    def access_token_for(api_token)
      ::MCP::Server::OAuth::AccessToken.new(
        token: "api_token:#{api_token.id}",
        client_id: "api_token:#{api_token.id}",
        subject: api_token.user_id.to_s,
        scopes: api_token.scopes,
        expires_at: api_token.expires_at&.to_i
      )
    end
  end
end
