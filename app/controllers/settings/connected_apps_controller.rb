module Settings
  # Lists the OAuth clients, such as Claude, that a user has connected to Edify, and lets them disconnect one (#323).
  # Disconnecting revokes every token and authorization code that client holds for the user, so its access ends
  # at once and it has to ask for consent again.
  class ConnectedAppsController < ::ApplicationController
    before_action :authenticate_user!
    after_action :verify_authorized

    # GET /settings/connected_apps
    def index
      authorize :connected_app
      @connected_apps = ::OauthApplication.connected_for(current_user).order(:name)
      # The connection guide is for leaders the MCP endpoint serves; everyone can still see and disconnect apps.
      @can_connect = current_user.assigned_to_unit? && ::EdifyMcp::Access.allowed?(current_user)
    end

    # DELETE /settings/connected_apps/:id
    def destroy
      authorize :connected_app
      application = ::OauthApplication.connected_for(current_user).find(params.expect(:id))

      ::OauthApplication.revoke_tokens_and_grants_for(application.id, current_user)
      redirect_to settings_connected_apps_path, notice: "Disconnected #{application.name}.", status: :see_other
    end
  end
end
