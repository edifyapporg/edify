# Personal access tokens belong to one user. Settings::ApiTokensController loads them only through
# current_user.api_tokens, so another user's token is never found, whatever the viewer's role. This policy decides
# only who may use the page.
class ApiTokenPolicy < ApplicationPolicy
  def index?
    user.assigned_to_unit?
  end

  def create?
    index?
  end

  # Ownership comes from the controller loading tokens through current_user.api_tokens. Revoking needs no unit,
  # so a user who has lost theirs can still cut off their own token.
  def revoke?
    true
  end
end
