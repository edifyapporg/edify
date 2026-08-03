# Finds likely-duplicate member records within a unit.
#
# The importer keys members on exact (name, birthdate), so an official name
# change (a new/added surname or middle name) produces a second record for one
# real person. We anchor on an identical birthdate (guaranteed to be a different
# name by the unique index) and then require the names to be related:
#
#   * surnames are equal or one is a subset of the other (e.g. a hyphenation
#     change like "Bentley-Dyches" -> "Dyches"), AND
#   * the shorter given-name is a prefix of the longer (e.g. "Kellianne" ->
#     "Kellianne Huntington", "Berkley" -> "Berkley Janet Noel").
#
# Requiring both keeps precision high and excludes same-birthdate siblings/twins
# (same surname, different first names). Pairs a reviewer has dismissed are
# skipped.
class DuplicateMemberFinder
  # @param unit [Unit]
  # @return [Array<DuplicateMemberPair>]
  def self.call(unit)
    new(unit).call
  end

  # @param unit [Unit]
  def initialize(unit)
    @unit = unit
  end

  # @return [Array<DuplicateMemberPair>]
  def call
    unit.members.to_a
        .group_by(&:birthdate)
        .each_value
        .flat_map { |members_sharing_birthdate| pairs_within(members_sharing_birthdate) }
        .sort_by { |pair| pair.keep.name }
  end

  private

  attr_reader :unit

  # @param members [Array<Member>]
  # @return [Array<DuplicateMemberPair>]
  def pairs_within(members)
    return [] if members.size < 2

    members.combination(2).filter_map do |first, second|
      next unless related?(first, second)
      next if dismissed?(first, second)

      keep, remove = keep_and_remove(first, second)
      DuplicateMemberPair.new(keep, remove)
    end
  end

  # @return [Boolean]
  def related?(first, second)
    surnames_related?(first, second) && given_names_related?(first, second)
  end

  # @return [Boolean]
  def surnames_related?(first, second)
    a = parse(first.name)[:surname]
    b = parse(second.name)[:surname]
    return false if a.empty? || b.empty?

    (a - b).empty? || (b - a).empty?
  end

  # @return [Boolean]
  def given_names_related?(first, second)
    a = parse(first.name)[:given]
    b = parse(second.name)[:given]
    return false if a.empty? || b.empty?

    shorter, longer = [a, b].sort_by(&:size)
    longer.first(shorter.size) == shorter
  end

  # Splits "Last, First Middle" into normalized surname and given-name tokens.
  # @return [Hash{Symbol=>Array<String>}]
  def parse(name)
    surname, given = name.to_s.split(",", 2)
    { surname: tokenize(surname), given: tokenize(given) }
  end

  # @return [Array<String>]
  def tokenize(part)
    part.to_s.downcase.gsub(/[^a-z\s-]/, " ").split(/[\s-]+/).compact_blank
  end

  # Keep the most current record: one still in the latest sync, then the most
  # recently synced, then the most recently created.
  # @return [Array(Member, Member)] keep, remove
  def keep_and_remove(first, second)
    [first, second].sort_by { |member| ordering_key(member) }
  end

  # @return [Array]
  def ordering_key(member)
    [
      member.not_in_most_recent_sync? ? 1 : 0,
      -(member.synced_on || Date.new(0)).jd,
      -member.created_at.to_i,
    ]
  end

  # @return [Boolean]
  def dismissed?(first, second)
    dismissed_pairs.include?([first.id, second.id].minmax)
  end

  # @return [Set<Array(Integer, Integer)>]
  def dismissed_pairs
    @dismissed_pairs ||= DuplicateDismissal.where(unit: unit)
                                           .pluck(:member_a_id, :member_b_id)
                                           .to_set
  end
end
