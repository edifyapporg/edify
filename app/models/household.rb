# A household as the member directory lists it: the shared name ("Adams, David & Erin"), the address, and the one
# phone number and email address the directory carries for the whole family. The people in it are HouseholdMembers,
# which link to Members where the individual directory has been imported for them.
class Household < ApplicationRecord
  belongs_to :unit
  has_many :household_members, -> { order(:position) }, dependent: :destroy, inverse_of: :household
  has_many :members, through: :household_members

  validates :name, presence: true, uniqueness: { scope: :unit_id }

  scope :alphabetized, -> { order(:name) }

  # The adults the household is named for. "Adams, David & Erin" names David and Erin; a household named for one
  # person names only them.
  # @return [ActiveRecord::Relation]
  def parents
    household_members.where(parent: true)
  end

  # @return [String]
  def address
    address_lines.join("\n")
  end

  # The surname the household's first-name-only entries belong to.
  # @return [String]
  def surname
    name.split(",").first.to_s.strip
  end
end
