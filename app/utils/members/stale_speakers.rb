module Members
  # Members who have not spoken in sacrament meeting for at least `months` months, or never have, with whoever has
  # waited longest first (those who have never spoken, then the oldest last talk). Shared by the API and, later, the
  # MCP tools (#315), so they give the same answer.
  #
  # A talk on a future meeting counts as the member's last talk, so someone already scheduled is not stale. Members
  # whose invitations are paused are left out, since they have asked not to be invited for now.
  class StaleSpeakers
    DEFAULT_MONTHS = 12
    MONTHS_RANGE = (1..120)
    DEFAULT_LIMIT = 25
    LIMIT_RANGE = (1..200)
    # The age groups clients see, by the Member#speaker_category each stands for. Leaders say "Primary", not "child".
    GROUPS = { "primary" => :child, "youth" => :youth, "adult" => :adult }.freeze

    # @param members [ActiveRecord::Relation<Member>] the roster to search, already scoped to what the user may see
    # @param months [Integer]
    # @param limit [Integer]
    # @param group [String, nil] a key of GROUPS, or nil for everyone
    # @return [Array<Member>] each answering #name and #last_talk_date (nil if they have never spoken)
    def self.call(members:, months: DEFAULT_MONTHS, limit: DEFAULT_LIMIT, group: nil)
      new(members: members, months: months, limit: limit, group: group).call
    end

    # @param member [Member]
    # @return [String] the GROUPS key for the member's speaker category
    def self.group_of(member)
      GROUPS.key(member.speaker_category)
    end

    # Everything a client may see about a stale speaker: name, gender, age group and last talk, and nothing else (no
    # age, birthdate, contact details or notes; see #315). The API and the MCP tools both answer with this.
    # @param member [Member] one returned by #call
    # @return [Hash]
    def self.speaker_json(member)
      {
        name: member.name,
        gender: member.gender,
        group: group_of(member),
        last_talk_date: member.last_talk_date,
      }
    end

    def initialize(members:, months:, limit:, group: nil)
      raise ArgumentError, "months must be within #{MONTHS_RANGE}" unless MONTHS_RANGE.cover?(months)
      raise ArgumentError, "limit must be within #{LIMIT_RANGE}" unless LIMIT_RANGE.cover?(limit)
      raise ArgumentError, "group must be one of #{GROUPS.keys.join(', ')}" unless group.nil? || GROUPS.key?(group)

      @members = members
      @months = months
      @limit = limit
      @group = group
    end

    # @return [Array<Member>]
    def call
      roster.with_last_talk_date
            .where("members.last_talk_date IS NULL OR members.last_talk_date < ?", spoken_before)
            .where("members.paused_until IS NULL OR members.paused_until <= ?", ::Date.current)
            .reorder(::Arel.sql("members.last_talk_date ASC NULLS FIRST, members.name ASC"))
            .limit(limit)
            .to_a
    end

    # Anyone whose last talk was before this date is stale.
    # @return [Date]
    def spoken_before
      months.months.ago.to_date
    end

    private

    attr_reader :members, :months, :limit, :group

    def roster
      group ? members.in_speaker_category(GROUPS.fetch(group)) : members
    end
  end
end
