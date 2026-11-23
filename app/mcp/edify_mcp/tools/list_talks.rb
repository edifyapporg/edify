module EdifyMcp
  module Tools
    # The MCP counterpart of GET /api/v1/talks, answering with the same filters, policy and serializer.
    class ListTalks < Tool
      TEXT_LENGTH = ::Talk::FILTER_TEXT_LENGTH
      LIMIT_RANGE = ::Talk::LISTING_LIMIT_RANGE
      DATE = { type: "string", pattern: "^\\d{4}-\\d{2}-\\d{2}$" }.freeze

      tool_name "list_talks"
      title "List talks"
      description <<~DESC.squish
        Lists the ward's sacrament meeting talks, newest first, each with the meeting date, the speaker's name, the
        talk's purpose and its topic. All filters are optional and can be combined: speaker (every word must appear
        in the speaker's name, recorded as "Last, First"), purpose (contained in the purpose, e.g. "missionary";
        common purposes are #{::Talk::DEFAULT_PURPOSE_LIST.join(', ')}), and a range of meeting dates. Use it to
        find when someone last spoke and on what, or who spoke for a purpose or in a period. It needs a bishopric or
        clerk role.
      DESC
      input_schema(
        properties: {
          speaker: {
            type: "string", minLength: TEXT_LENGTH.min, maxLength: TEXT_LENGTH.max,
            description: "Words from the speaker's name, e.g. a last name, or a first and last name."
          },
          purpose: {
            type: "string", minLength: TEXT_LENGTH.min, maxLength: TEXT_LENGTH.max,
            description: "Text the talk's purpose contains, e.g. \"missionary\" or \"youth\"."
          },
          from: DATE.merge(description: "First meeting date to include, as YYYY-MM-DD."),
          to: DATE.merge(description: "Last meeting date to include, as YYYY-MM-DD."),
          limit: {
            type: "integer", minimum: LIMIT_RANGE.min, maximum: LIMIT_RANGE.max,
            description: "Most talks to return. Default #{::Talk::LISTING_DEFAULT_LIMIT}."
          },
        },
        # The ward always comes from the token, so anything else (a unit id, for one) is refused rather than ignored.
        additionalProperties: false
      )
      annotations(read_only_hint: true, destructive_hint: false, idempotent_hint: true, open_world_hint: false)

      class << self
        def call(server_context:, speaker: nil, purpose: nil, from: nil, to: nil,
                 limit: ::Talk::LISTING_DEFAULT_LIMIT)
          log_call(server_context, { speaker: speaker, purpose: purpose, from: from, to: to, limit: limit })
          user = current_user(server_context)
          return not_authorized unless authorized?(user, ::Talk, :index?)

          speaker = speaker&.squish
          purpose = purpose&.squish
          error = filter_error(speaker:, purpose:, from:, to:)
          return respond_with_error(error) if error

          from &&= ::Date.iso8601(from)
          to &&= ::Date.iso8601(to)
          talks = user.unit.talks.filtered(speaker:, purpose:, from:, to:).limit(limit)
          respond_with(speaker:, purpose:, from:, to:, limit:,
                       talks: talks.map { |talk| ::TalkSummarySerializer.call(talk) })
        end

        private

        # The schema checks lengths and the date shape; this catches what it can't: words made only of spaces, dates
        # such as 2026-02-30, and a range that ends before it starts.
        def filter_error(speaker:, purpose:, from:, to:)
          { speaker:, purpose: }.each do |name, value|
            if value && value.length < TEXT_LENGTH.min
              return "The #{name} filter needs at least #{TEXT_LENGTH.min} letters besides spaces."
            end
          end
          [from, to].each do |value|
            return "#{value} is not a real date. Use YYYY-MM-DD." if value && !real_date?(value)
          end
          "The to date must not be before the from date." if from && to && ::Date.iso8601(to) < ::Date.iso8601(from)
        end

        def real_date?(value)
          ::Date.iso8601(value)
          true
        rescue ::Date::Error
          false
        end
      end
    end
  end
end
