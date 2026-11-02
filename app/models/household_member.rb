# One name listed under a household. The household directory gives a name and, for younger members, an age -- never a
# gender or a birthdate -- so this can never stand in for a Member. It records what the directory said and points at
# the Member when the individual directory has been imported for that person.
class HouseholdMember < ApplicationRecord
  belongs_to :household
  belongs_to :member, optional: true

  validates :name, presence: true
  validates :position, presence: true, uniqueness: { scope: :household_id }

  scope :matched, -> { where.not(member_id: nil) }
  scope :unmatched, -> { where(member_id: nil) }

  # @return [Boolean] whether the directory listed an age, which it does only for the younger members of a household
  def minor?
    listed_age.present?
  end
end
