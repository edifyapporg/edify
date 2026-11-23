module EdifyMcp
  module Tools
    # The MCP counterpart of GET /api/v1/songs/recent, answering with the same query and the same fields.
    class ListRecentSongs < Tool
      RecentlySung = ::Songs::RecentlySung

      tool_name "list_recent_songs"
      title "List recently sung hymns"
      description <<~DESC.squish
        Lists the hymns the ward has sung in sacrament meeting over the last few weeks, counted by title: most sung
        first, then most recently sung. Each result gives the title (with its hymn number), how many times it was
        sung, the date it was last sung, and the song types it was sung as (opening_hymn, sacrament_hymn,
        congregational_hymn, musical_number or closing_hymn). Prelude and postlude are not counted, and only meetings
        up to today count. Use it to avoid repeating hymns or to see which have been used most.
      DESC
      input_schema(
        properties: {
          weeks: {
            type: "integer", minimum: RecentlySung::WEEKS_RANGE.min, maximum: RecentlySung::WEEKS_RANGE.max,
            description: "How many weeks back to count, ending today. Default #{RecentlySung::DEFAULT_WEEKS}."
          },
          limit: {
            type: "integer", minimum: RecentlySung::LIMIT_RANGE.min, maximum: RecentlySung::LIMIT_RANGE.max,
            description: "Most hymns to return. Default #{RecentlySung::DEFAULT_LIMIT}."
          },
          song_type: {
            type: "string", enum: RecentlySung::COUNTED_TYPES,
            description: "Count only songs sung as this type, e.g. sacrament_hymn. Omit for every type."
          },
        },
        # The ward always comes from the token, so anything else (a unit id, for one) is refused rather than ignored.
        additionalProperties: false
      )
      annotations(read_only_hint: true, destructive_hint: false, idempotent_hint: true, open_world_hint: false)

      class << self
        def call(server_context:, weeks: RecentlySung::DEFAULT_WEEKS, limit: RecentlySung::DEFAULT_LIMIT,
                 song_type: nil)
          log_call(server_context, { weeks: weeks, limit: limit, song_type: song_type })
          user = current_user(server_context)
          return not_authorized unless authorized?(user, ::Song, :recent?)

          query = RecentlySung.new(unit: user.unit, weeks: weeks, limit: limit, song_type: song_type)
          respond_with(
            weeks: weeks,
            song_type: song_type,
            since: query.since,
            songs: query.call.map { |tally| ::SongTallySerializer.call(tally) }
          )
        end
      end
    end
  end
end
