require "rails_helper"

RSpec.describe "MCP list_talks" do
  include McpHelpers

  let(:user) { users(:sunny_bishopric) }
  let(:unit) { units(:sunny_hills) }
  let(:api_token) { ::ApiToken.create!(user: user, name: "Claude Code") }
  let(:auth) { { "Authorization" => "Bearer #{api_token.plaintext_token}" } }

  def talk(on:, speaker:, purpose: nil, topic: nil, in_unit: unit, **attributes)
    meeting = in_unit.meetings.find_or_create_by!(date: on) { |m| m.meeting_type = :sacrament_meeting }
    meeting.talks.create!(speaker_name: speaker, purpose: purpose, topic: topic, **attributes)
  end

  def dates
    mcp_result.dig("structuredContent", "talks").pluck("date")
  end

  before do
    host! "localhost"
    talk(on: Date.new(2027, 1, 10), speaker: "Zz, Jane Smith", purpose: "Departing Missionary", topic: "Faith")
    talk(on: Date.new(2027, 2, 14), speaker: "Zz, John Smith", purpose: "Stake Representative", topic: "Hope",
         member: members(:bartell_randal))
    talk(on: Date.new(2027, 3, 7), speaker: "Zz, Jane Smith", topic: "Charity")
    talk(on: Date.new(2027, 3, 7), speaker: "Zz, Other Ward", in_unit: units(:pleasant_forest))
  end

  it "answers what GET /api/v1/talks answers, for the user's own unit" do
    mcp_call("list_talks", from: "2027-01-01")

    expect(mcp_result["isError"]).to be(false)
    expect(mcp_result["structuredContent"]).to eq(
      "speaker" => nil, "purpose" => nil, "from" => "2027-01-01", "to" => nil, "limit" => 50,
      "talks" => [
        { "date" => "2027-03-07", "speaker" => "Zz, Jane Smith", "purpose" => nil, "topic" => "Charity" },
        { "date" => "2027-02-14", "speaker" => "Zz, John Smith", "purpose" => "Stake Representative",
          "topic" => "Hope" },
        { "date" => "2027-01-10", "speaker" => "Zz, Jane Smith", "purpose" => "Departing Missionary",
          "topic" => "Faith" },
      ]
    )
  end

  it "applies the speaker, purpose, date and limit filters together" do
    mcp_call("list_talks", speaker: " jane  smith ", purpose: "missionary", from: "2027-01-01", to: "2027-12-31",
                           limit: 5)

    expect(mcp_result["structuredContent"]).to include("speaker" => "jane smith", "purpose" => "missionary",
                                                       "to" => "2027-12-31", "limit" => 5)
    expect(dates).to eq(["2027-01-10"])
  end

  it "never includes the linked member or their details" do
    mcp_call("list_talks", from: "2027-01-01")
    expect(response.body).not_to include("member", members(:bartell_randal).phone_number.to_s)
  end

  [
    [{ speaker: "    " }, "The speaker filter needs at least 2 letters besides spaces."],
    [{ from: "2027-02-30" }, "2027-02-30 is not a real date. Use YYYY-MM-DD."],
    [{ from: "2027-03-01", to: "2027-02-01" }, "The to date must not be before the from date."],
  ].each do |arguments, message|
    it "explains #{arguments}" do
      mcp_call("list_talks", **arguments)
      expect(mcp_result["isError"]).to be(true)
      expect(mcp_error_text).to eq(message)
    end
  end

  [{ speaker: "z" }, { from: "1/1/2027" }, { limit: 0 }, { unit_id: 2 }].each do |arguments|
    it "refuses #{arguments} by its schema" do
      mcp_call("list_talks", **arguments)
      expect(mcp_result["isError"]).to be(true)
      expect(mcp_error_text).to start_with("Invalid arguments")
    end
  end

  context "with a program role, which cannot see the talks page" do
    let(:user) { users(:sunny_program) }

    it "answers with a tool error" do
      mcp_call("list_talks")
      expect(mcp_error_text).to eq("Your Edify role does not have access to this.")
    end
  end

  it "logs the filters, but not the results" do
    allow(Rails.logger).to receive(:info)

    mcp_call("list_talks", purpose: "missionary")

    expect(Rails.logger).to have_received(:info)
      .with(/tool=list_talks .* arguments=\{"purpose":"missionary","limit":50\}/)
    expect(Rails.logger).not_to have_received(:info).with(/Zz, Jane Smith/)
  end
end
