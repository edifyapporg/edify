module Members
  # Headless policy for the Possible Duplicates feature. Gated on the same access
  # as Imports (bishopric/clerk), including the destructive merge, per product
  # choice. Resolved via `authorize [:members, :possible_duplicate], :action?`.
  class PossibleDuplicatePolicy < ApplicationPolicy
    def index?
      user.access_to_lcr?
    end

    def summary?
      user.access_to_lcr?
    end

    def merge?
      user.access_to_lcr?
    end

    def dismiss?
      user.access_to_lcr?
    end
  end
end
