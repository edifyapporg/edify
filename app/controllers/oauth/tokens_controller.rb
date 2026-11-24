module Oauth
  # Doorkeeper's token endpoint (#323), refusing any `resource` other than the MCP endpoint (RFC 8707). Claude sends
  # `resource` on both the code exchange and refreshes.
  class TokensController < ::Doorkeeper::TokensController
    before_action :refuse_other_resources, only: :create

    private

    def refuse_other_resources
      resource = params[:resource]
      return if resource.blank? || ::Oauth::McpResource.matches?(resource, request)

      render json: { error: "invalid_target", error_description: "Edify issues tokens only for its MCP endpoint." },
             status: :bad_request
    end
  end
end
