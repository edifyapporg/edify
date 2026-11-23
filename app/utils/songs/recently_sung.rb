module Songs
  # The hymns a unit has sung in sacrament meeting over the last `weeks` weeks, counted by title: most sung first,
  # then most recently sung. Shared by the API and, later, the MCP tools (#315), so they give the same answer.
  #
  # Like Unit#song_last_sung, prelude and postlude are left out, and titles match whatever their capitalization or
  # spacing. Only meetings up to today count, so songs planned for future meetings are not "sung" yet. Asking for one
  # song type, such as sacrament_hymn, counts only songs sung as that type.
  class RecentlySung
    DEFAULT_WEEKS = 12
    WEEKS_RANGE = (1..104)
    DEFAULT_LIMIT = 50
    LIMIT_RANGE = (1..200)
    INSTRUMENTAL_TYPES = %w[prelude postlude].freeze
    # The Song#song_type values counted, in program order (the enum's order).
    COUNTED_TYPES = (::Song.song_types.keys - INSTRUMENTAL_TYPES).freeze

    # One hymn's tally. `title` is spelled as it was most recently entered, and `song_types` lists the distinct types
    # it was sung as, in program order.
    Tally = ::Data.define(:title, :times_sung, :last_sung, :song_types) do
      def to_json_hash
        {
          title: title,
          times_sung: times_sung,
          last_sung: last_sung,
          song_types: song_types,
        }
      end
    end

    # @param unit [Unit]
    # @param weeks [Integer]
    # @param limit [Integer]
    # @param song_type [String, nil] one of COUNTED_TYPES, or nil for all of them
    # @return [Array<Tally>]
    def self.call(unit:, weeks: DEFAULT_WEEKS, limit: DEFAULT_LIMIT, song_type: nil)
      new(unit: unit, weeks: weeks, limit: limit, song_type: song_type).call
    end

    def initialize(unit:, weeks:, limit:, song_type: nil)
      raise ArgumentError, "weeks must be within #{WEEKS_RANGE}" unless WEEKS_RANGE.cover?(weeks)
      raise ArgumentError, "limit must be within #{LIMIT_RANGE}" unless LIMIT_RANGE.cover?(limit)
      unless song_type.nil? || COUNTED_TYPES.include?(song_type)
        raise ArgumentError, "song_type must be one of #{COUNTED_TYPES.join(', ')}"
      end

      @unit = unit
      @weeks = weeks
      @limit = limit
      @song_type = song_type
    end

    # @return [Array<Tally>]
    def call
      sung_songs.group_by { |title, _date, _type| title.squish.downcase }
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

    attr_reader :unit, :weeks, :limit, :song_type

    # @return [Array<Array(String, Date, String)>] title, meeting date and type of every counted song, newest first
    def sung_songs
      unit.songs
          .where(meetings: { date: since..::Date.current })
          .where(song_type: song_type || COUNTED_TYPES)
          .where.not(title: [nil, ""])
          .reorder("meetings.date desc")
          .pluck(:title, "meetings.date", :song_type)
    end

    def tally(sung)
      latest_title, latest_date, = sung.first
      types = sung.map(&:third).uniq.sort_by { |type| COUNTED_TYPES.index(type) }
      Tally.new(title: latest_title.squish, times_sung: sung.size, last_sung: latest_date, song_types: types)
    end
  end
end
