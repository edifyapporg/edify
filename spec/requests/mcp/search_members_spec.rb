require "rails_helper"

RSpec.describe "MCP search_members" do
  include McpHelpers

  let(:user) { users(:sunny_bishopric) }
  let(:unit) { units(:sunny_hills) }
  let(:api_token) { ::ApiToken.create!(user: user, name: "Claude Code") }
  let(:auth) { { "Authorization" => "Bearer #{api_token.plaintext_token}" } }

  def create_member(name, in_unit: unit, **attributes)
    in_unit.members.create!(name: name, gender: :female, birthdate: "1980-01-01", synced_on: in_unit.last_synced_on,
                            phone_number: "303-555-0100", email: "member@example.com", **attributes)
  end

  before do
    host! "localhost"
    create_member("Zzsmith, John", gender: :male)
    create_member("Zzsmith, Ann", birthdate: 15.years.ago.to_date)
    create_member("Zzsmith, Other Ward", in_unit: units(:pleasant_forest))
  end

  it "answers what GET /api/v1/members answers, for the user's own unit" do
    mcp_call("search_members", query: "zzsmith")

    expect(mcp_result["isError"]).to be(false)
    expect(mcp_result["structuredContent"]).to eq(
      "query" => "zzsmith",
      "limit" => 25,
      "members" => [
        { "name" => "Zzsmith, Ann", "gender" => "female", "group" => "youth" },
        { "name" => "Zzsmith, John", "gender" => "male", "group" => "adult" },
      ]
    )
  end

  it "matches every word in any order, and uses the limit asked for" do
    mcp_call("search_members", query: "john   zzsmith", limit: 5)

    content = mcp_result["structuredContent"]
    expect(content).to include("query" => "john zzsmith", "limit" => 5)
    expect(content["members"].pluck("name")).to eq(["Zzsmith, John"])
  end

  # The exact member keys are pinned above; the JSON-RPC envelope has its own "id", so this checks contact details.
  it "never includes contact details or birthdates" do
    mcp_call("search_members", query: "zzsmith")
    expect(response.body).not_to include("303-555-0100", "@example.com", "1980-01-01", "birthdate")
  end

  it "says when the query is only spaces" do
    mcp_call("search_members", query: "    ")
    expect(mcp_result["isError"]).to be(true)
    expect(mcp_error_text).to eq("The query needs at least 2 letters besides spaces.")
  end

  [{ query: "z" }, {}, { query: "zzsmith", limit: 101 }, { query: "zzsmith", unit_id: 2 }].each do |arguments|
    it "refuses #{arguments} by its schema" do
      mcp_call("search_members", **arguments)
      expect(mcp_result["isError"]).to be(true)
      expect(mcp_error_text).to match(/\A(Invalid|Missing required) arguments/)
    end
  end

  context "with a music role, which cannot see the members page" do
    let(:user) { users(:sunny_music) }

    it "answers with a tool error" do
      mcp_call("search_members", query: "zzsmith")
      expect(mcp_result["isError"]).to be(true)
      expect(mcp_error_text).to eq("Your Edify role does not have access to this.")
    end
  end

  it "logs the query, but not the results" do
    allow(Rails.logger).to receive(:info)

    mcp_call("search_members", query: "zzsmith")

    expect(Rails.logger).to have_received(:info)
      .with(/tool=search_members .* arguments=\{"query":"zzsmith","limit":25\}/)
    expect(Rails.logger).not_to have_received(:info).with(/Zzsmith, Ann/)
  end
end
