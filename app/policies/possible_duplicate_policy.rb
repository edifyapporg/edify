# Headless policy for the Possible Duplicates page. Gated on the same access as
# Imports (bishopric/clerk), including the destructive merge, per product choice.
class PossibleDuplicatePolicy < ApplicationPolicy
  def index?
    user.access_to_lcr?
  end

  def merge?
    user.access_to_lcr?
  end

  def dismiss?
    user.access_to_lcr?
  end
end
