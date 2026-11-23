require "rails_helper"

RSpec.describe ::Songs::RecentlySung do
  let(:unit) { units(:sunny_hills) }

  around { |example| travel_to(Date.new(2026, 6, 15)) { example.run } }

  def sing(title, on:, type: :opening_hymn, in_unit: unit)
    meeting = in_unit.meetings.find_or_create_by!(date: on) { |m| m.meeting_type = :sacrament_meeting }
    meeting.songs.create!(title: title, song_type: type)
  end

  def result(**)
    described_class.call(unit: unit, **).map(&:to_json_hash)
  end

  it "counts each hymn sung in the last 12 weeks, most sung first, then most recent" do
    sing("Come, Follow Me #116", on: Date.new(2026, 6, 7))
    sing("Come, Follow Me #116", on: Date.new(2026, 5, 3), type: :closing_hymn)
    sing("I Stand All Amazed #193", on: Date.new(2026, 6, 14), type: :sacrament_hymn)
    sing("Abide with Me #166", on: Date.new(2026, 5, 31))

    expected = [
      { title: "Come, Follow Me #116", times_sung: 2, last_sung: Date.new(2026, 6, 7) },
      { title: "I Stand All Amazed #193", times_sung: 1, last_sung: Date.new(2026, 6, 14) },
      { title: "Abide with Me #166", times_sung: 1, last_sung: Date.new(2026, 5, 31) },
    ]
    expect(result).to eq(expected)
  end

  it "counts a hymn as one title whatever its capitalization or spacing, spelled as most recently entered" do
    sing("come follow me #116", on: Date.new(2026, 5, 3))
    sing("Come Follow  Me #116 ", on: Date.new(2026, 6, 7))

    expect(result).to eq([{ title: "Come Follow Me #116", times_sung: 2, last_sung: Date.new(2026, 6, 7) }])
  end

  it "leaves out prelude and postlude, as the last-sung check does" do
    sing("Prelude Medley", on: Date.new(2026, 6, 7), type: :prelude)
    sing("Postlude in G", on: Date.new(2026, 6, 7), type: :postlude)
    sing("Musical Number", on: Date.new(2026, 6, 7), type: :musical_number)

    expect(result.pluck(:title)).to eq(["Musical Number"])
  end

  it "counts only meetings from the start of the window through today" do
    sing("Today", on: Date.new(2026, 6, 15))
    sing("First Day", on: 12.weeks.ago.to_date)
    sing("Too Early", on: 12.weeks.ago.to_date - 1)
    sing("Planned", on: Date.new(2026, 6, 21))

    expect(result.pluck(:title)).to contain_exactly("Today", "First Day")
  end

  it "uses the weeks and limit asked for" do
    sing("Recent", on: Date.new(2026, 6, 7))
    sing("Older", on: Date.new(2026, 2, 1))

    expect(result(weeks: 52).pluck(:title)).to contain_exactly("Recent", "Older")
    expect(result(weeks: 52, limit: 1).pluck(:title)).to eq(["Recent"])
    expect(described_class.new(unit: unit, weeks: 4, limit: 50).since).to eq(Date.new(2026, 5, 18))
  end

  it "counts only the unit's own meetings" do
    sing("Other Ward Hymn", on: Date.new(2026, 6, 7), in_unit: units(:pleasant_forest))
    expect(result).to be_empty
  end

  it "rejects weeks and limits outside the allowed ranges" do
    expect { result(weeks: 0) }.to raise_error(ArgumentError, /weeks/)
    expect { result(weeks: 105) }.to raise_error(ArgumentError, /weeks/)
    expect { result(limit: 0) }.to raise_error(ArgumentError, /limit/)
    expect { result(limit: 201) }.to raise_error(ArgumentError, /limit/)
  end
end
