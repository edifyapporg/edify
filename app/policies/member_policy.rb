class MemberPolicy < ApplicationPolicy
  # Hiding moved members is a view preference on the roster, not an edit to
  # member data, so anyone who can see the roster may set their own.
  def moved_filter?
    index?
  end
end
