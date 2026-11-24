module Oauth
  # OAuth 2.0 Protected Resource Metadata (RFC 9728) for the MCP endpoint (#323). The 401 from /mcp points here, and
  # clients that don't get that pointer probe /.well-known/oauth-protected-resource/mcp and then the root path, so both
  # serve it. It names Edify, on the host the request arrived at, as the only authorization server, matching the
  # issuer in Oauth::MetadataController.
  class ProtectedResourceMetadataController < ::ActionController::API
    def show
      render json: {
        resource: ::Oauth::McpResource.url(request),
        authorization_servers: [request.base_url],
        scopes_supported: ::Doorkeeper.config.scopes.to_a,
        bearer_methods_supported: ["header"],
        resource_name: "Edify",
      }
    end
  end
end
