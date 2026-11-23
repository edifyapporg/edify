require "rails_helper"

RSpec.describe ::TalkSummarySerializer do
  it "gives the meeting date, speaker, purpose and topic, never the linked member" do
    meeting = ::Meeting.new(date: Date.new(2026, 11, 8))
    talk = ::Talk.new(meeting: meeting, position: 2, speaker_name: "Doe, Jane", purpose: "Youth Speaker",
                      topic: "Faith", member: members(:bartell_randal))

    expect(described_class.call(talk)).to eq(date: Date.new(2026, 11, 8), speaker: "Doe, Jane",
                                             purpose: "Youth Speaker", topic: "Faith")
  end
end
