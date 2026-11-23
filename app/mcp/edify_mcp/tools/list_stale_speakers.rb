module EdifyMcp
  module Tools
    # The MCP counterpart of GET /api/v1/speakers/stale, answering with the same query and the same fields.
    class ListStaleSpeakers < Tool
      StaleSpeakers = ::Members::StaleSpeakers

      tool_name "list_stale_speakers"
      title "List stale speakers"
      description <<~DESC.squish
        Lists ward members ordered by how long since they last spoke in sacrament meeting: those who have never
        spoken first, then the longest since their last talk. Members already scheduled to speak and members whose
        invitations are paused are left out. Each result gives the member's name, gender, age group (primary, youth
        or adult) and last talk date (null if never). Use it to suggest who to invite to speak.
      DESC
      input_schema(
        properties: {
          months: {
            type: "integer", minimum: StaleSpeakers::MONTHS_RANGE.min, maximum: StaleSpeakers::MONTHS_RANGE.max,
            description: "Members who have not spoken in at least this many months. Default #{StaleSpeakers::DEFAULT_MONTHS}."
          },
          limit: {
            type: "integer", minimum: StaleSpeakers::LIMIT_RANGE.min, maximum: StaleSpeakers::LIMIT_RANGE.max,
            description: "Most members to return. Default #{StaleSpeakers::DEFAULT_LIMIT}."
          },
          group: {
            type: "string", enum: StaleSpeakers::GROUPS.keys,
            description: "Only this age group: primary (children 8-11), youth (12-17) or adult. Omit for everyone."
          },
        },
        # The ward always comes from the token, so anything else (a unit id, for one) is refused rather than ignored.
        additionalProperties: false
      )
      annotations(read_only_hint: true, destructive_hint: false, idempotent_hint: true, open_world_hint: false)

      class << self
        def call(server_context:, months: StaleSpeakers::DEFAULT_MONTHS, limit: StaleSpeakers::DEFAULT_LIMIT,
                 group: nil)
          log_call(server_context, { months: months, limit: limit, group: group })
          user = current_user(server_context)
          return not_authorized unless authorized?(user, :speaker, :stale?)

          query = StaleSpeakers.new(members: user.unit.visible_members_for(user), months: months, limit: limit,
                                    group: group)
          respond_with(
            months: months,
            group: group,
            spoken_before: query.spoken_before,
            speakers: query.call.map { |member| ::StaleSpeakerSerializer.call(member) }
          )
        end
      end
    end
  end
end
