module EdifyMcp
  module Tools
    # The MCP counterpart of GET /api/v1/members, answering with the same roster, policy and serializer.
    class SearchMembers < Tool
      QUERY_LENGTH = ::Member::SEARCH_QUERY_LENGTH
      LIMIT_RANGE = ::Member::SEARCH_LIMIT_RANGE

      tool_name "search_members"
      title "Search members by name"
      description <<~DESC.squish
        Finds ward members by name. Every word of the query must appear in the member's name, in any order and
        ignoring case; names are recorded as "Last, First", so "jane smith" finds "Smith, Jane". Each result gives the
        member's name, gender and age group (primary, youth or adult), and nothing else. Use it to confirm how a
        member's name is recorded or to tell two similar names apart. It needs a bishopric or clerk role.
      DESC
      input_schema(
        properties: {
          query: {
            type: "string", minLength: QUERY_LENGTH.min, maxLength: QUERY_LENGTH.max,
            description: "Words from the member's name, e.g. a last name, or a first and last name."
          },
          limit: {
            type: "integer", minimum: LIMIT_RANGE.min, maximum: LIMIT_RANGE.max,
            description: "Most members to return. Default #{::Member::SEARCH_DEFAULT_LIMIT}."
          },
        },
        required: ["query"],
        # The ward always comes from the token, so anything else (a unit id, for one) is refused rather than ignored.
        additionalProperties: false
      )
      annotations(read_only_hint: true, destructive_hint: false, idempotent_hint: true, open_world_hint: false)

      class << self
        def call(query:, server_context:, limit: ::Member::SEARCH_DEFAULT_LIMIT)
          log_call(server_context, { query: query, limit: limit })
          user = current_user(server_context)
          return not_authorized unless authorized?(user, ::Member, :index?)

          words = query.squish
          unless QUERY_LENGTH.cover?(words.length)
            return respond_with_error("The query needs at least #{QUERY_LENGTH.min} letters besides spaces.")
          end

          members = user.unit.visible_members_for(user).matching_name(words).alphabetized.limit(limit)
          respond_with(query: words, limit: limit, members: members.map { |member| ::MemberSerializer.call(member) })
        end
      end
    end
  end
end
