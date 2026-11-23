require "rails_helper"

RSpec.describe ::Meetings::InDateRange do
  let(:unit) { units(:sunny_hills) }

  def meeting(on, in_unit: unit)
    in_unit.meetings.create!(date: on, meeting_type: :sacrament_meeting)
  end

  it "returns the unit's meetings in the range, inclusive, earliest first" do
    later = meeting(Date.new(2026, 12, 6))
    first_day = meeting(Date.new(2026, 11, 1))
    meeting(Date.new(2026, 10, 25))
    meeting(Date.new(2026, 12, 13))
    meeting(Date.new(2026, 11, 8), in_unit: units(:pleasant_forest))

    expect(described_class.call(unit: unit, from: Date.new(2026, 11, 1), to: Date.new(2026, 12, 6)))
      .to eq([first_day, later])
  end

  it "defaults the end to 84 days after the start" do
    inside = meeting(Date.new(2026, 11, 1) + 84)
    meeting(Date.new(2026, 11, 1) + 85)

    expect(described_class.call(unit: unit, from: Date.new(2026, 11, 1))).to eq([inside])
  end

  it "rejects an end before the start, or a range longer than 366 days" do
    from = Date.new(2026, 11, 1)
    expect { described_class.call(unit: unit, from: from, to: from - 1) }.to raise_error(ArgumentError, /before/)
    expect { described_class.call(unit: unit, from: from, to: from + 367) }.to raise_error(ArgumentError, /366/)
    expect { described_class.call(unit: unit, from: from, to: from + 366) }.not_to raise_error
  end
end
