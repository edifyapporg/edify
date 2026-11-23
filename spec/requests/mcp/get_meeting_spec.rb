require "rails_helper"

RSpec.describe "MCP get_meeting" do
  include McpHelpers

  let(:user) { users(:sunny_bishopric) }
  let(:unit) { units(:sunny_hills) }
  let(:api_token) { ::ApiToken.create!(user: user, name: "Claude Code") }
  let(:auth) { { "Authorization" => "Bearer #{api_token.plaintext_token}" } }

  before do
    user.update!(admin: true)
    host! "localhost"
    unit.meetings.create!(date: Date.new(2026, 11, 8), meeting_type: :sacrament_meeting,
                          presider_name: "Bishop Young").tap do |m|
      m.talks.create!(speaker_name: "Smith, Jane", topic: "Gratitude", member: members(:bartell_randal))
      m.songs.create!(song_type: :opening_hymn, title: "Come, Follow Me #116")
    end
  end

  it "answers with the meeting as GET /api/v1/meetings/:date does" do
    mcp_call("get_meeting", date: "2026-11-08")

    expect(mcp_result["isError"]).to be(false)
    content = mcp_result["structuredContent"]
    expect(content.keys).to eq(%w[date meeting_type contributors talks songs])
    expect(content).to include("date" => "2026-11-08", "meeting_type" => "sacrament_meeting")
    expect(content["contributors"]).to include("presider" => "Bishop Young")
    expect(content["talks"]).to eq([{ "position" => 1, "speaker" => "Smith, Jane", "purpose" => nil,
                                      "topic" => "Gratitude" }])
    expect(content["songs"]).to eq([{ "song_type" => "opening_hymn", "title" => "Come, Follow Me #116" }])
  end

  it "never includes the linked member's details" do
    mcp_call("get_meeting", date: "2026-11-08")
    expect(response.body).not_to include("member", members(:bartell_randal).phone_number)
  end

  it "says when the ward has no meeting that day" do
    mcp_call("get_meeting", date: "2026-11-15")
    expect(mcp_result["isError"]).to be(true)
    expect(mcp_error_text).to eq("The ward has no meeting on 2026-11-15.")
  end

  it "refuses a date that isn't real" do
    mcp_call("get_meeting", date: "2026-02-30")
    expect(mcp_result["isError"]).to be(true)
    expect(mcp_error_text).to eq("2026-02-30 is not a real date. Use YYYY-MM-DD.")
  end

  [{ date: "11/8/2026" }, {}, { date: "2026-11-08", unit_id: 2 }].each do |arguments|
    it "refuses #{arguments} by its schema" do
      mcp_call("get_meeting", **arguments)
      expect(mcp_result["isError"]).to be(true)
      expect(mcp_error_text).to match(/\A(Invalid|Missing required) arguments/)
    end
  end

  context "with an admin from another unit" do
    let(:user) { users(:pleasant_one) }

    it "finds no meeting where only the first unit has one" do
      mcp_call("get_meeting", date: "2026-11-08")
      expect(mcp_error_text).to eq("The ward has no meeting on 2026-11-08.")
    end
  end
end
