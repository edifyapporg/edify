module Api
  module V1
    class MeetingsController < BaseController
      InDateRange = ::Meetings::InDateRange
      ApiJson = ::Meetings::ApiJson
      ISO_DATE = /\A\d{4}-\d{2}-\d{2}\z/

      # GET /api/v1/meetings?from=2026-11-01&to=2027-01-31
      # The unit's meetings in the range, earliest first, with their speakers. `from` defaults to today and `to` to
      # 84 days after `from`; the range may span at most 366 days.
      def index
        authorize ::Meeting, :index?

        from = params.key?(:from) ? parse_date(params[:from]) : ::Date.current
        return invalid_request(date_message(:from)) unless from

        to = params.key?(:to) ? parse_date(params[:to]) : InDateRange.default_to(from)
        error = to ? range_message(from, to) : date_message(:to)
        return invalid_request(error) if error

        render json: {
          from: from,
          to: to,
          meetings: InDateRange.call(unit: current_unit, from: from, to: to).map { |m| ApiJson.summary(m) },
        }
      end

      # GET /api/v1/meetings/2026-11-08
      # One meeting of the unit, with the people taking part, its talks and its songs.
      def show
        authorize ::Meeting, :show?

        date = parse_date(params[:date])
        return invalid_request(date_message(:date)) unless date

        meeting = current_unit.meetings.includes(:talks, :songs).find_by!(date: date)
        render json: ApiJson.detail(meeting)
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

        "The range may span at most #{InDateRange::MAX_SPAN_DAYS} days." if (to - from) > InDateRange::MAX_SPAN_DAYS
      end
    end
  end
end
