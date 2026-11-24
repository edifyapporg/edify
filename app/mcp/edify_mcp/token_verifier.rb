module EdifyMcp
  # Lets the MCP SDK's transport accept Edify's two kinds of bearer token: personal access tokens (#317), which start
  # with ApiToken::PREFIX, and OAuth access tokens that a leader authorized for a client such as Claude (#323). The
  # transport calls #verify on every request and answers a rejection with 401 and a WWW-Authenticate challenge itself.
  # The returned AccessToken reaches tools as `server_context.auth_info`, with the user's id as its subject. Either
  # kind of token is refused for a user without a unit, or one for whom MCP isn't enabled yet.
  class TokenVerifier < ::MCP::Server::OAuth::TokenVerifier
    InvalidToken = ::MCP::Server::OAuth::InvalidTokenError

    # @param token [String] the raw bearer token
    # @return [MCP::Server::OAuth::AccessToken]
    # @raise [MCP::Server::OAuth::InvalidTokenError] for an unknown, revoked or expired token, a user without a unit, or
    #   a user for whom MCP is not yet enabled. The messages reach the client in a header, so they carry no token data.
    def verify(token)
      token.start_with?(::ApiToken::PREFIX) ? verify_api_token(token) : verify_oauth_token(token)
    end

    private

    def verify_api_token(token)
      api_token = ::ApiToken.authenticate(token)
      raise InvalidToken, "The API token is invalid, revoked or expired." unless api_token

      check_user!(api_token.user)
      api_token.touch_last_used!
      ::MCP::Server::OAuth::AccessToken.new(
        token: "api_token:#{api_token.id}",
        client_id: "api_token:#{api_token.id}",
        subject: api_token.user_id.to_s,
        scopes: api_token.scopes,
        expires_at: api_token.expires_at&.to_i
      )
    end

    # Edify's authorization server issues tokens only for this endpoint, so every live OAuth token's audience is /mcp.
    def verify_oauth_token(token)
      oauth_token = ::OauthAccessToken.by_token(token)
      raise InvalidToken, "The access token is invalid, revoked or expired." unless oauth_token&.accessible?

      user = ::User.find_by(id: oauth_token.resource_owner_id)
      raise InvalidToken, "The access token is invalid, revoked or expired." unless user

      check_user!(user)
      # As Doorkeeper's own resource protection does: the client has now used the access token from its last refresh,
      # so the refresh token it exchanged for it stops working.
      oauth_token.revoke_previous_refresh_token!
      access_token_for(oauth_token)
    end

    def check_user!(user)
      raise InvalidToken, "Your Edify account is not assigned to a unit." unless user.assigned_to_unit?
      raise InvalidToken, "Edify's MCP server is not enabled for your account yet." unless Access.allowed?(user)
    end

    # Identifies the token by record id rather than carrying the secret any further.
    def access_token_for(oauth_token)
      ::MCP::Server::OAuth::AccessToken.new(
        token: "oauth_token:#{oauth_token.id}",
        client_id: oauth_token.application.uid,
        subject: oauth_token.resource_owner_id.to_s,
        scopes: oauth_token.scopes.to_a,
        expires_at: (oauth_token.created_at + oauth_token.expires_in.seconds).to_i
      )
    end
  end
end
