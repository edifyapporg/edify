module Api
  module V1
    class SongsController < BaseController
      RecentlySung = ::Songs::RecentlySung

      # GET /api/v1/songs/recent?weeks=12&limit=50
      # Hymns the user's unit has sung in the last `weeks` weeks, most sung first, then most recent. Prelude and
      # postlude are left out, and only meetings up to today count.
      def recent
        authorize ::Song, :recent?

        weeks = integer_param(:weeks, RecentlySung::DEFAULT_WEEKS)
        limit = integer_param(:limit, RecentlySung::DEFAULT_LIMIT)
        error = range_error(:weeks, weeks, RecentlySung::WEEKS_RANGE) ||
                range_error(:limit, limit, RecentlySung::LIMIT_RANGE)
        return invalid_request(error) if error

        query = RecentlySung.new(unit: current_unit, weeks: weeks, limit: limit)

        render json: {
          weeks: weeks,
          since: query.since,
          songs: query.call.map(&:to_json_hash),
        }
      end
    end
  end
end
