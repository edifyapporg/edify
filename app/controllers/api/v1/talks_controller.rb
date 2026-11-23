module Api
  module V1
    class TalksController < BaseController
      DEFAULT_LIMIT = ::Talk::LISTING_DEFAULT_LIMIT
      LIMIT_RANGE = ::Talk::LISTING_LIMIT_RANGE
      TEXT_LENGTH = ::Talk::FILTER_TEXT_LENGTH
      # Marks a parameter that was given but is not usable, as distinct from one that was left out.
      INVALID = Object.new.freeze

      # GET /api/v1/talks?speaker=smith&purpose=missionary&from=2025-01-01&to=2025-12-31&limit=50
      # The unit's talks, newest first, optionally narrowed by speaker (every word in the name), purpose (contains,
      # ignoring case) and meeting dates (inclusive), as on the talks page.
      def index
        authorize ::Talk, :index?

        speaker = text_param(:speaker)
        purpose = text_param(:purpose)
        from = date_param(:from)
        to = date_param(:to)
        limit = integer_param(:limit, DEFAULT_LIMIT)
        error = filter_error(speaker:, purpose:, from:, to:) || range_error(:limit, limit, LIMIT_RANGE)
        return invalid_request(error) if error

        render json: {
          speaker: speaker,
          purpose: purpose,
          from: from,
          to: to,
          limit: limit,
          talks: current_unit.talks.filtered(speaker:, purpose:, from:, to:).limit(limit)
                             .map { |talk| ::TalkSummarySerializer.call(talk) },
        }
      end

      private

      # @return [String, nil, INVALID] the squished text, nil when absent, or INVALID
      def text_param(name)
        return unless params.key?(name)

        value = params[name]
        text = value.squish if value.is_a?(String)
        text && TEXT_LENGTH.cover?(text.length) ? text : INVALID
      end

      # @return [Date, nil, INVALID]
      def date_param(name)
        return unless params.key?(name)

        parse_date(params[name]) || INVALID
      end

      # @return [String, nil]
      def filter_error(speaker:, purpose:, from:, to:)
        { speaker:, purpose: }.each do |name, value|
          return "#{name} must be from #{TEXT_LENGTH.min} to #{TEXT_LENGTH.max} characters." if value.equal?(INVALID)
        end
        { from:, to: }.each { |name, value| return date_message(name) if value.equal?(INVALID) }
        "to must not be before from." if from && to && to < from
      end
    end
  end
end
