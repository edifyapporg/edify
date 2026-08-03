# Records a member pair that a reviewer confirmed is NOT a duplicate, so the
# Possible Duplicates page stops surfacing it. Pairs are stored order-independent
# (lower member id in member_a) so a dismissal matches regardless of the order
# the two members were compared in.
class DuplicateDismissal < ApplicationRecord
  belongs_to :unit
  belongs_to :member_a, class_name: "Member"
  belongs_to :member_b, class_name: "Member"

  validates :member_a_id, uniqueness: { scope: :member_b_id }

  # Finds or builds the dismissal for a pair, normalizing member order by id.
  # @return [DuplicateDismissal]
  def self.for(member_one, member_two)
    lower, higher = [member_one, member_two].minmax_by(&:id)
    find_or_initialize_by(member_a: lower, member_b: higher)
  end
end
