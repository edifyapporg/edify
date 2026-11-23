module Api
  module V1
    class SpeakersController < BaseController
      StaleSpeakers = ::Members::StaleSpeakers

      # GET /api/v1/speakers/stale?months=12&limit=25&group=youth
      # Members of the user's unit who have not spoken in `months` months, or never have, longest-waiting first,
      # optionally only one age group. Returns names, gender, age group and last-talk dates only: never exact ages,
      # birthdates, contact details or notes.
      def stale
        authorize :speaker, :stale?

        months = integer_param(:months, StaleSpeakers::DEFAULT_MONTHS)
        limit = integer_param(:limit, StaleSpeakers::DEFAULT_LIMIT)
        group = params[:group]
        error = range_error(:months, months, StaleSpeakers::MONTHS_RANGE) ||
                range_error(:limit, limit, StaleSpeakers::LIMIT_RANGE) ||
                group_error(group)
        return invalid_request(error) if error

        query = StaleSpeakers.new(members: current_unit.visible_members_for(current_user),
                                  months: months,
                                  limit: limit,
                                  group: group)

        render json: {
          months: months,
          group: group,
          spoken_before: query.spoken_before,
          speakers: query.call.map { |member| ::StaleSpeakerSerializer.call(member) },
        }
      end

      private

      # @return [String, nil] a message when a group is given but is not one of StaleSpeakers::GROUPS
      def group_error(group)
        return if !params.key?(:group) || StaleSpeakers::GROUPS.key?(group)

        "group must be one of #{StaleSpeakers::GROUPS.keys.join(', ')}."
      end
    end
  end
end
