module Oauth
  # Doorkeeper's sign-in and consent step (#323), in Edify's layout. After Doorkeeper's own sign-in check, and before
  # any consent is shown or recorded, it refuses:
  #
  # - an admin impersonating a leader, whose consent would mint tokens owned by that leader and outliving the
  #   impersonation;
  # - a user with no unit, whom the MCP endpoint wouldn't serve, so no token is issued that /mcp would only answer
  #   with 401, which a client takes as a cue to ask for consent again;
  # - any `resource` other than the MCP endpoint (RFC 8707).
  #
  # Then it resolves the client's Client ID Metadata Document. This signed-in step is the only place Edify fetches
  # one: the token and revoke endpoints, which anyone can call, only look up clients already resolved here.
  class AuthorizationsController < ::Doorkeeper::AuthorizationsController
    layout "application"

    before_action :refuse_impersonation, :refuse_without_unit, :refuse_other_resources,
                  :resolve_client_metadata_document, only: [:new, :create]

    private

    # Doorkeeper's hook after a code is issued. Denials and token refreshes never reach it.
    def after_successful_authorization(context)
      super
      loopback = ::OauthApplication.loopback_redirect?(::URI.parse(pre_auth.redirect_uri))
      ::AccountSecurityMailer.app_connected(current_user, pre_auth.client.application, loopback: loopback).deliver_later
    end

    def refuse_impersonation
      return if true_user == current_user

      render_unavailable "Stop impersonating to connect an app",
                         "Apps can only be connected by leaders signed in as themselves."
    end

    def refuse_without_unit
      return if current_user.assigned_to_unit?

      render_unavailable "Connecting apps needs a ward",
                         "Your Edify account isn't assigned to a ward yet, so there's nothing for an app to read."
    end

    def refuse_other_resources
      resource = params[:resource]
      return if resource.blank? || ::Oauth::McpResource.matches?(resource, request)

      render_unavailable "This connection can't be made",
                         "The app asked for access to something other than Edify's MCP server. Try connecting " \
                         "again with #{::Oauth::McpResource.url(request)} as the server URL.",
                         status: :bad_request
    end

    def resolve_client_metadata_document
      client_id = params[:client_id]
      return unless ::Oauth::ClientIdMetadataDocument.client_id?(client_id)

      ::Oauth::ClientIdMetadataDocument.new(client_id).application
    end

    def render_unavailable(title, message, status: :forbidden)
      render "oauth/authorizations/unavailable", locals: { title: title, message: message }, status: status
    end
  end
end
