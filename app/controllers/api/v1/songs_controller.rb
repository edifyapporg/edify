module Api
  module V1
    class SongsController < BaseController
      RecentlySung = ::Songs::RecentlySung

      # GET /api/v1/songs/recent?weeks=12&limit=50&song_type=sacrament_hymn
      # Hymns the user's unit has sung in the last `weeks` weeks, most sung first, then most recent, each with the
      # types it was sung as. Prelude and postlude are left out, and only meetings up to today count. `song_type`
      # counts only songs sung as that type.
      def recent
        authorize ::Song, :recent?

        weeks = integer_param(:weeks, RecentlySung::DEFAULT_WEEKS)
        limit = integer_param(:limit, RecentlySung::DEFAULT_LIMIT)
        song_type = params[:song_type]
        error = range_error(:weeks, weeks, RecentlySung::WEEKS_RANGE) ||
                range_error(:limit, limit, RecentlySung::LIMIT_RANGE) ||
                song_type_error(song_type)
        return invalid_request(error) if error

        query = RecentlySung.new(unit: current_unit, weeks: weeks, limit: limit, song_type: song_type)

        render json: {
          weeks: weeks,
          song_type: song_type,
          since: query.since,
          songs: query.call.map { |tally| ::SongTallySerializer.call(tally) },
        }
      end

      private

      # @return [String, nil] a message when a song type is given but is not one that is counted
      def song_type_error(song_type)
        return if !params.key?(:song_type) || RecentlySung::COUNTED_TYPES.include?(song_type)

        "song_type must be one of #{RecentlySung::COUNTED_TYPES.join(', ')}."
      end
    end
  end
end
