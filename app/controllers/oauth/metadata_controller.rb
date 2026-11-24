module Oauth
  # OAuth 2.0 Authorization Server Metadata (RFC 8414) at /.well-known/oauth-authorization-server (#323). MCP clients
  # read it to find Edify's endpoints and learn that it takes Client ID Metadata Documents, S256 PKCE and public
  # clients. The issuer is the host the request arrived at, which is the host the MCP endpoint's protected resource
  # metadata names.
  class MetadataController < ::ActionController::API
    def show
      render json: {
        issuer: request.base_url,
        authorization_endpoint: oauth_authorization_url,
        token_endpoint: oauth_token_url,
        revocation_endpoint: oauth_revoke_url,
        response_types_supported: ["code"],
        grant_types_supported: %w[authorization_code refresh_token],
        code_challenge_methods_supported: ::Doorkeeper.config.pkce_code_challenge_methods,
        token_endpoint_auth_methods_supported: ["none"],
        revocation_endpoint_auth_methods_supported: ["none"],
        scopes_supported: ::Doorkeeper.config.scopes.to_a,
        client_id_metadata_document_supported: true,
      }
    end
  end
end
