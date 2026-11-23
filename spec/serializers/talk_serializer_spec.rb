require "rails_helper"

RSpec.describe ::TalkSerializer do
  it "gives position, speaker, purpose and topic, never the linked member" do
    talk = ::Talk.new(position: 2, speaker_name: "Doe, Jane", purpose: "Youth Speaker", topic: "Faith",
                      member: members(:bartell_randal))

    expect(described_class.call(talk)).to eq(position: 2, speaker: "Doe, Jane", purpose: "Youth Speaker",
                                             topic: "Faith")
  end
end
