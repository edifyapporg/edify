require "rails_helper"

RSpec.describe "MCP list_recent_songs" do
  include McpHelpers

  let(:user) { users(:sunny_bishopric) }
  let(:unit) { units(:sunny_hills) }
  let(:api_token) { ::ApiToken.create!(user: user, name: "Claude Code") }
  let(:auth) { { "Authorization" => "Bearer #{api_token.plaintext_token}" } }

  around { |example| travel_to(Date.new(2026, 6, 15)) { example.run } }

  before do
    host! "localhost"
    sing("Come, Follow Me #116", on: Date.new(2026, 6, 7), type: :opening_hymn)
    sing("Come, Follow Me #116", on: Date.new(2026, 5, 3), type: :closing_hymn)
    sing("I Stand All Amazed #193", on: Date.new(2026, 6, 14), type: :sacrament_hymn)
    sing("Other Ward Hymn", on: Date.new(2026, 6, 7), type: :opening_hymn, in_unit: units(:pleasant_forest))
  end

  def sing(title, on:, type:, in_unit: unit)
    meeting = in_unit.meetings.find_or_create_by!(date: on) { |m| m.meeting_type = :sacrament_meeting }
    meeting.songs.create!(title: title, song_type: type)
  end

  it "answers what GET /api/v1/songs/recent answers, for the user's own unit" do
    mcp_call("list_recent_songs")

    expect(mcp_result["isError"]).to be(false)
    expect(mcp_result["structuredContent"]).to eq(
      "weeks" => 12,
      "song_type" => nil,
      "since" => "2026-03-23",
      "songs" => [
        { "title" => "Come, Follow Me #116", "times_sung" => 2, "last_sung" => "2026-06-07",
          "song_types" => %w[opening_hymn closing_hymn] },
        { "title" => "I Stand All Amazed #193", "times_sung" => 1, "last_sung" => "2026-06-14",
          "song_types" => ["sacrament_hymn"] },
      ]
    )
  end

  it "uses the weeks, limit and song type asked for" do
    mcp_call("list_recent_songs", weeks: 4, limit: 5, song_type: "sacrament_hymn")

    content = mcp_result["structuredContent"]
    expect(content).to include("weeks" => 4, "song_type" => "sacrament_hymn", "since" => "2026-05-18")
    expect(content["songs"].pluck("title")).to eq(["I Stand All Amazed #193"])
  end

  [{ song_type: "prelude" }, { weeks: 0 }, { unit_id: 2 }].each do |arguments|
    it "refuses #{arguments}" do
      expect(::Songs::RecentlySung).not_to receive(:new)
      mcp_call("list_recent_songs", **arguments)
      expect(mcp_result["isError"]).to be(true)
    end
  end

  context "with a program role, which sees songs on the meetings page" do
    let(:user) { users(:sunny_program) }

    it "is allowed" do
      mcp_call("list_recent_songs")
      expect(mcp_result["isError"]).to be(false)
    end
  end

  it "logs the call's arguments" do
    allow(Rails.logger).to receive(:info)
    mcp_call("list_recent_songs", song_type: "sacrament_hymn")
    expect(Rails.logger).to have_received(:info)
      .with(/tool=list_recent_songs .* arguments=\{"weeks":12,"limit":50,"song_type":"sacrament_hymn"\}/)
  end
end
