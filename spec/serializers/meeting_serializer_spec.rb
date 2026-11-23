require "rails_helper"

RSpec.describe ::MeetingSerializer do
  let(:meeting) do
    ::Meeting.new(date: Date.new(2026, 11, 8), meeting_type: :sacrament_meeting, presider_name: "Bishop Young",
                  scheduler: users(:sunny_bishopric)).tap do |m|
      m.talks.build(position: 1, speaker_name: "Doe, Jane")
      m.songs.build(song_type: :opening_hymn, title: "Come, Follow Me #116")
    end
  end

  it "gives date, type, contributors, talks and songs, never the scheduler" do
    result = described_class.call(meeting)

    expect(result.keys).to eq(%i[date meeting_type contributors talks songs])
    expect(result[:contributors]).to eq(presider: "Bishop Young", conductor: nil, chorister: nil, organist: nil,
                                        opening_prayer: nil, closing_prayer: nil)
    expect(result[:talks]).to eq([{ position: 1, speaker: "Doe, Jane", purpose: nil, topic: nil }])
    expect(result.to_s).not_to include(users(:sunny_bishopric).email)
  end
end
