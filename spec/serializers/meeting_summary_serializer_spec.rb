require "rails_helper"

RSpec.describe ::MeetingSummarySerializer do
  let(:meeting) do
    ::Meeting.new(date: Date.new(2026, 11, 8), meeting_type: :sacrament_meeting, presider_name: "Bishop Young",
                  scheduler: users(:sunny_bishopric)).tap do |m|
      m.talks.build(position: 1, speaker_name: "Doe, Jane")
      m.songs.build(song_type: :opening_hymn, title: "Come, Follow Me #116")
    end
  end

  it "gives date, type and speakers" do
    expect(described_class.call(meeting))
      .to eq(date: Date.new(2026, 11, 8), meeting_type: "sacrament_meeting", speakers: ["Doe, Jane"])
  end
end
