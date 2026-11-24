# Connected apps belong to one user. Settings::ConnectedAppsController finds them only through
# OauthApplication.connected_for(current_user), so another user's connections are never found, whatever the viewer's
# role. Any signed-in user may see and disconnect their own, with or without a unit, so a user who has lost theirs
# can still cut off a client.
class ConnectedAppPolicy < ApplicationPolicy
  def index?
    true
  end

  def destroy?
    true
  end
end
