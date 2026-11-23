module Api
  module V1
    class MeetingsController < BaseController
      ISO_DATE = /\A\d{4}-\d{2}-\d{2}\z/

      # GET /api/v1/meetings?from=2026-11-01&to=2027-01-31
      # The unit's meetings in the range, earliest first, with their speakers. `from` defaults to today and `to` to
      # Meeting::DEFAULT_LISTING_DAYS after `from`; the range may span at most Meeting::MAX_LISTING_DAYS.
      def index
        authorize ::Meeting, :index?

        from = params.key?(:from) ? parse_date(params[:from]) : ::Date.current
        return invalid_request(date_message(:from)) unless from

        to = params.key?(:to) ? parse_date(params[:to]) : from + ::Meeting::DEFAULT_LISTING_DAYS
        error = to ? range_message(from, to) : date_message(:to)
        return invalid_request(error) if error

        meetings = current_unit.meetings.occurring_between(from, to).order(:date).includes(:talks)

        render json: {
          from: from,
          to: to,
          meetings: meetings.map { |meeting| ::MeetingSummarySerializer.call(meeting) },
        }
      end

      # GET /api/v1/meetings/2026-11-08
      # One meeting of the unit, with the people taking part, its talks and its songs.
      def show
        authorize ::Meeting, :show?

        date = parse_date(params[:date])
        return invalid_request(date_message(:date)) unless date

        meeting = current_unit.meetings.includes(:talks, :songs).find_by!(date: date)
        render json: ::MeetingSerializer.call(meeting)
      end

      private

      # @return [Date, nil] nil unless the value is a real date written as YYYY-MM-DD
      def parse_date(value)
        ::Date.iso8601(value) if value.is_a?(String) && value.match?(ISO_DATE)
      rescue ::Date::Error
        nil
      end

      def date_message(name)
        "#{name} must be a date written as YYYY-MM-DD."
      end

      # @return [String, nil]
      def range_message(from, to)
        return "to must not be before from." if to < from

        "The range may span at most #{::Meeting::MAX_LISTING_DAYS} days." if (to - from) > ::Meeting::MAX_LISTING_DAYS
      end
    end
  end
end
