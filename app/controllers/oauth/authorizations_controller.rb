module Oauth
  # Doorkeeper's sign-in and consent step (#323), in Edify's layout, refusing any `resource` other than the MCP
  # endpoint (RFC 8707) before showing or recording consent.
  class AuthorizationsController < ::Doorkeeper::AuthorizationsController
    layout "application"

    before_action :refuse_other_resources, only: [:new, :create]

    private

    def refuse_other_resources
      resource = params[:resource]
      return if resource.blank? || ::Oauth::McpResource.matches?(resource, request)

      render "oauth/authorizations/invalid_resource", status: :bad_request
    end
  end
end
