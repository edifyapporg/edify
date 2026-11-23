module Songs
  # The hymns a unit has sung in sacrament meeting over the last `weeks` weeks, counted by title: most sung first,
  # then most recently sung. Shared by the API and, later, the MCP tools (#315), so they give the same answer.
  #
  # Like Unit#song_last_sung, prelude and postlude are left out, and titles match whatever their capitalization or
  # spacing. Only meetings up to today count, so songs planned for future meetings are not "sung" yet.
  class RecentlySung
    DEFAULT_WEEKS = 12
    WEEKS_RANGE = (1..104)
    DEFAULT_LIMIT = 50
    LIMIT_RANGE = (1..200)
    INSTRUMENTAL_TYPES = %i[prelude postlude].freeze

    # One hymn's tally. `title` is spelled as it was most recently entered.
    Tally = ::Data.define(:title, :times_sung, :last_sung) do
      def to_json_hash
        { title: title, times_sung: times_sung, last_sung: last_sung }
      end
    end

    # @param unit [Unit]
    # @param weeks [Integer]
    # @param limit [Integer]
    # @return [Array<Tally>]
    def self.call(unit:, weeks: DEFAULT_WEEKS, limit: DEFAULT_LIMIT)
      new(unit: unit, weeks: weeks, limit: limit).call
    end

    def initialize(unit:, weeks:, limit:)
      raise ArgumentError, "weeks must be within #{WEEKS_RANGE}" unless WEEKS_RANGE.cover?(weeks)
      raise ArgumentError, "limit must be within #{LIMIT_RANGE}" unless LIMIT_RANGE.cover?(limit)

      @unit = unit
      @weeks = weeks
      @limit = limit
    end

    # @return [Array<Tally>]
    def call
      sung_songs.group_by { |title, _date| title.squish.downcase }
                .map { |_key, sung| tally(sung) }
                .sort_by { |t| [-t.times_sung, -t.last_sung.jd, t.title.downcase] }
                .first(limit)
    end

    # The first day counted.
    # @return [Date]
    def since
      weeks.weeks.ago.to_date
    end

    private

    attr_reader :unit, :weeks, :limit

    # @return [Array<Array(String, Date)>] title and meeting date of every counted song, newest first
    def sung_songs
      unit.songs
          .where(meetings: { date: since..::Date.current })
          .where.not(song_type: INSTRUMENTAL_TYPES)
          .where.not(title: [nil, ""])
          .reorder("meetings.date desc")
          .pluck(:title, "meetings.date")
    end

    def tally(sung)
      latest_title, latest_date = sung.first
      Tally.new(title: latest_title.squish, times_sung: sung.size, last_sung: latest_date)
    end
  end
end
