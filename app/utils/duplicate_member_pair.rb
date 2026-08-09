# A candidate pair of member records that may represent the same person.
# +keep+ is the record a merge should preserve (the most current one) and
# +remove+ is the stale record that would be deleted.
#
# Defined with Ruby's immutable Data class (a pair never changes after it's
# built) and wired into ActiveModel so it participates in Rails' dom_id/record
# conventions -- dom_id(pair) yields "duplicate_member_pair_<lower>-<higher>",
# keeping the Turbo frame id logic in exactly one place.
DuplicateMemberPair = Data.define(:keep, :remove) do
  extend ActiveModel::Naming
  include ActiveModel::Conversion

  # Order-independent identifier for the pair, used for DOM/Turbo frame ids.
  # @return [String]
  def id
    [keep.id, remove.id].minmax.join("-")
  end
end
