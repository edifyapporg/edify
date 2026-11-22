# Personal access tokens belong to one user. Only users assigned to a unit can list or create them. No role, not even
# unit admin or site admin, can see or revoke another user's tokens, but a user can always revoke their own, even
# after losing their unit, since revoking only ever removes access.
class ApiTokenPolicy < ApplicationPolicy
  def index?
    user.assigned_to_unit?
  end

  def create?
    index?
  end

  def revoke?
    record.user_id == user.id
  end

  class Scope < Scope
    def resolve
      scope.where(user: user)
    end
  end
end
