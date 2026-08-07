# A candidate pair of member records that may represent the same person.
# +keep+ is the record a merge should preserve (the most current one) and
# +remove+ is the stale record that would be deleted.
class DuplicateMemberPair
  attr_reader :keep, :remove

  # @param keep [Member]
  # @param remove [Member]
  def initialize(keep, remove)
    @keep = keep
    @remove = remove
  end

  # Order-independent identifier for the pair, used for DOM/Turbo frame ids.
  # @return [String]
  def id
    [keep.id, remove.id].minmax.join("-")
  end
end
