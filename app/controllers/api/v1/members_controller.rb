module Api
  module V1
    class MembersController < BaseController
      QUERY_LENGTH = (2..100)
      DEFAULT_LIMIT = 25
      LIMIT_RANGE = (1..100)

      # GET /api/v1/members?q=smith&limit=25
      # Members of the user's unit whose name contains every word of `q`, alphabetically, from the same roster as the
      # members page. Returns name, gender and age group only.
      def index
        authorize ::Member, :index?

        # Read by hand rather than with params.expect, so a missing or non-text q gets the API's 422 error shape.
        raw_query = params[:q]
        query = raw_query.squish if raw_query.is_a?(String)
        limit = integer_param(:limit, DEFAULT_LIMIT)
        error = query_error(query) || range_error(:limit, limit, LIMIT_RANGE)
        return invalid_request(error) if error

        members = current_unit.visible_members_for(current_user).matching_name(query).alphabetized.limit(limit)

        render json: {
          query: query,
          limit: limit,
          members: members.map { |member| ::MemberSerializer.call(member) },
        }
      end

      private

      # @return [String, nil]
      def query_error(query)
        return if query && QUERY_LENGTH.cover?(query.length)

        "q must be from #{QUERY_LENGTH.min} to #{QUERY_LENGTH.max} characters."
      end
    end
  end
end
