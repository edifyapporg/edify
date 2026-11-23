module Meetings
  # A unit's meetings from one date through another, earliest first, with their talks loaded. Shared by the API and,
  # later, the MCP tools (#315).
  class InDateRange
    # With no end date, this many days from the start.
    DEFAULT_SPAN_DAYS = 84
    # The longest range one request may ask for.
    MAX_SPAN_DAYS = 366

    # @param unit [Unit]
    # @param from [Date]
    # @param to [Date, nil] defaults to DEFAULT_SPAN_DAYS after `from`
    # @return [Array<Meeting>]
    def self.call(unit:, from:, to: nil)
      new(unit: unit, from: from, to: to).call
    end

    # @return [Date]
    def self.default_to(from)
      from + DEFAULT_SPAN_DAYS
    end

    def initialize(unit:, from:, to: nil)
      @unit = unit
      @from = from
      @to = to || self.class.default_to(from)
      raise ArgumentError, "to must not be before from" if @to < from
      raise ArgumentError, "the range must be at most #{MAX_SPAN_DAYS} days" if (@to - from) > MAX_SPAN_DAYS
    end

    # @return [Array<Meeting>]
    def call
      unit.meetings.where(date: from..to).order(:date).includes(:talks).to_a
    end

    private

    attr_reader :unit, :from, :to
  end
end
