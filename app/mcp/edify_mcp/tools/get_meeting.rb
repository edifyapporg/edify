module EdifyMcp
  module Tools
    # The MCP counterpart of GET /api/v1/meetings/:date, answering with the same serializer.
    class GetMeeting < Tool
      ISO_DATE_PATTERN = /\A\d{4}-\d{2}-\d{2}\z/

      tool_name "get_meeting"
      title "Get a meeting"
      description <<~DESC.squish
        Gets the ward's meeting on one date: its type (sacrament_meeting, testimony_meeting, ward_conference,
        stake_conference, general_conference, primary_program or musical_testimony); who presides and conducts, the
        chorister, organist and prayers, by name; its talks in order, with each speaker's name, purpose and topic; and
        its songs in program order with their types. Meetings are usually on Sundays. Use it to see what is planned for
        a Sunday or what happened in a past meeting.
      DESC
      input_schema(
        properties: {
          date: {
            type: "string", pattern: "^\\d{4}-\\d{2}-\\d{2}$",
            description: "The meeting's date, as YYYY-MM-DD."
          },
        },
        required: ["date"],
        # The ward always comes from the token, so anything else (a unit id, for one) is refused rather than ignored.
        additionalProperties: false
      )
      annotations(read_only_hint: true, destructive_hint: false, idempotent_hint: true, open_world_hint: false)

      class << self
        def call(date:, server_context:)
          log_call(server_context, { date: date })
          user = current_user(server_context)
          return not_authorized unless authorized?(user, ::Meeting, :show?)

          parsed = parse_date(date)
          return respond_with_error("#{date} is not a real date. Use YYYY-MM-DD.") unless parsed

          meeting = user.unit.meetings.includes(:talks, :songs).find_by(date: parsed)
          return respond_with_error("The ward has no meeting on #{parsed.iso8601}.") unless meeting

          respond_with(::MeetingSerializer.call(meeting))
        end

        private

        # The schema already checks the shape; this catches dates such as 2026-02-30.
        def parse_date(value)
          ::Date.iso8601(value) if value.match?(ISO_DATE_PATTERN)
        rescue ::Date::Error
          nil
        end
      end
    end
  end
end
