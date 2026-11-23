module Api
  module V1
    class SpeakersController < BaseController
      StaleSpeakers = ::Members::StaleSpeakers

      # GET /api/v1/speakers/stale?months=12&limit=25
      # Members of the user's unit who have not spoken in `months` months, or never have, longest-waiting first.
      # Returns names and dates only.
      def stale
        authorize :speaker, :stale?

        months = integer_param(:months, StaleSpeakers::DEFAULT_MONTHS)
        limit = integer_param(:limit, StaleSpeakers::DEFAULT_LIMIT)
        error = range_error(:months, months, StaleSpeakers::MONTHS_RANGE) ||
                range_error(:limit, limit, StaleSpeakers::LIMIT_RANGE)
        return invalid_request(error) if error

        query = StaleSpeakers.new(members: current_unit.visible_members_for(current_user), months: months, limit: limit)

        render json: {
          months: months,
          spoken_before: query.spoken_before,
          speakers: query.call.map { |member| { name: member.name, last_talk_date: member.last_talk_date } },
        }
      end

      private

      # Accepts plain digits only. Kernel#Integer would also read "010" as octal 8, "0x10" as 16 and "1_2" as 12.
      # @return [Integer, nil] the default when absent, nil unless the value is plain digits
      def integer_param(name, default)
        return default unless params.key?(name)

        value = params[name]
        value.to_i if value.is_a?(String) && value.match?(/\A\d+\z/)
      end

      # @return [String, nil] a message when the value is missing or outside the range
      def range_error(name, value, range)
        "#{name} must be a whole number from #{range.min} to #{range.max}." unless value && range.cover?(value)
      end
    end
  end
end
