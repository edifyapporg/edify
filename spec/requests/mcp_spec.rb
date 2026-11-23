require "rails_helper"

RSpec.describe "MCP endpoint" do
  let(:user) { users(:sunny_bishopric) }
  let(:unit) { units(:sunny_hills) }
  let(:api_token) { ::ApiToken.create!(user: user, name: "Claude Code") }
  let(:auth) { { "Authorization" => "Bearer #{api_token.plaintext_token}" } }
  let(:json) { response.parsed_body }
  let!(:never_spoke) do
    unit.members.create!(name: "Zz, Never Spoke", gender: :female, birthdate: "1980-01-01",
                         synced_on: unit.last_synced_on)
  end

  # Admins may use MCP until it is enabled for everyone; most examples run as an admin bishopric member.
  before do
    user.update!(admin: true)
    host! "localhost"
  end

  def rpc(method, params = {}, headers: auth)
    post "/mcp", params: { jsonrpc: "2.0", id: 1, method: method, params: params }.to_json,
                 headers: { "Content-Type" => "application/json", "Accept" => "application/json, text/event-stream",
                            "MCP-Protocol-Version" => "2025-11-25" }.merge(headers)
  end

  def call_tool(headers: auth, **arguments)
    rpc("tools/call", { name: "list_stale_speakers", arguments: arguments }, headers: headers)
  end

  def tool_result
    json.fetch("result")
  end

  describe "the protocol" do
    it "initializes without a session, with instructions about privacy" do
      rpc("initialize", { protocolVersion: "2025-11-25", capabilities: {}, clientInfo: { name: "spec", version: "1" } })

      expect(response).to have_http_status(:ok)
      expect(response.headers["Mcp-Session-Id"]).to be_nil
      expect(json.dig("result", "serverInfo", "name")).to eq("edify")
      expect(json.dig("result", "instructions")).to include("own ward only", "never ages, birthdates, contact details")
    end

    it "lists every tool as read-only, closed to unknown arguments" do
      rpc("tools/list")

      tools = json.dig("result", "tools")
      expect(tools.pluck("name")).to eq(%w[list_stale_speakers list_recent_songs get_meeting search_members])
      expect(tools.pluck("annotations")).to all(include("readOnlyHint" => true, "destructiveHint" => false))
      expect(tools.map { it.dig("inputSchema", "additionalProperties") }).to all(be(false))
    end

    it "lists list_stale_speakers with its arguments" do
      rpc("tools/list")

      tool = json.dig("result", "tools").find { it["name"] == "list_stale_speakers" }
      expect(tool["annotations"]).to include("readOnlyHint" => true, "destructiveHint" => false)
      expect(tool.dig("inputSchema", "properties").keys).to contain_exactly("months", "limit", "group")
      expect(tool.dig("inputSchema", "properties", "group", "enum")).to eq(%w[primary youth adult])
    end

    it "does not open streams or sessions" do
      get "/mcp", headers: auth.merge("Accept" => "text/event-stream")
      expect(response).to have_http_status(:method_not_allowed)
    end
  end

  describe "list_stale_speakers" do
    it "returns the user's unit's stale speakers with name, gender, group and last talk date only" do
      freeze_time do
        call_tool(limit: 200)

        expect(tool_result["isError"]).to be(false)
        content = tool_result["structuredContent"]
        expect(content).to include("months" => 12, "group" => nil, "spoken_before" => 12.months.ago.to_date.iso8601)
        expect(content["speakers"].map(&:keys).uniq).to eq([%w[name gender group last_talk_date]])
        expect(content["speakers"]).to include(
          "name" => never_spoke.name, "gender" => "female", "group" => "adult", "last_talk_date" => nil
        )
        expect(JSON.parse(tool_result.dig("content", 0, "text"))).to eq(content)
      end
    end

    it "never includes contact details, notes, ages or birthdates" do
      call_tool(limit: 200)
      expect(response.body).not_to include("@", "phone", "email", "note", "birthdate", never_spoke.birthdate.iso8601)
    end

    it "uses the months, limit and group asked for" do
      call_tool(months: 24, limit: 1, group: "adult")

      content = tool_result["structuredContent"]
      expect(content).to include("months" => 24, "group" => "adult")
      expect(content["speakers"].length).to eq(1)
      expect(content["speakers"].pluck("group")).to eq(["adult"])
    end

    it "rejects arguments outside the allowed ranges without running the query" do
      expect(::Members::StaleSpeakers).not_to receive(:new)
      call_tool(months: 0)
      expect(tool_result).to include("isError" => true)
      expect(tool_result.dig("content", 0, "text")).to include("/months", "less than: 1")
    end

    it "refuses a unit id, since the ward always comes from the token" do
      expect(::Members::StaleSpeakers).not_to receive(:new)
      call_tool(limit: 200, unit_id: units(:pleasant_forest).id)
      expect(tool_result).to include("isError" => true)
      expect(tool_result.dig("content", 0, "text")).to include("/unit_id", "disallowed additional property")
    end

    context "with an admin from another unit" do
      let(:user) { users(:pleasant_one) }

      it "sees only their own unit's members" do
        call_tool(limit: 200)
        expect(tool_result.dig("structuredContent", "speakers").pluck("name")).not_to include(never_spoke.name)
      end
    end

    context "with a role that cannot see the roster" do
      let(:user) { users(:sunny_music) }

      it "answers with a tool error" do
        call_tool
        expect(tool_result).to include("isError" => true)
        expect(tool_result.dig("content", 0, "text")).to eq("Your Edify role does not have access to this.")
      end
    end

    it "logs the user, tool and arguments, but no member data" do
      allow(Rails.logger).to receive(:info)

      call_tool(months: 6)

      expect(Rails.logger).to have_received(:info)
        .with(/\[mcp\] tool=list_stale_speakers user_id=#{user.id} token=api_token:#{api_token.id} arguments=\{"months":6,"limit":25\}/)
      expect(Rails.logger).not_to have_received(:info).with(/#{never_spoke.name}/)
    end

    it "records when the token was used" do
      expect { call_tool }.to change { api_token.reload.last_used_at }.from(nil)
    end
  end

  describe "authentication and access" do
    def expect_unauthorized(message = nil)
      expect(response).to have_http_status(:unauthorized)
      expect(response.headers["WWW-Authenticate"]).to start_with("Bearer")
      expect(response.headers["WWW-Authenticate"]).to include(message) if message
    end

    it "challenges a request without a token" do
      call_tool(headers: {})
      expect_unauthorized
    end

    it "refuses an unknown token" do
      call_tool(headers: { "Authorization" => "Bearer edify_not_a_real_token" })
      expect_unauthorized("invalid, revoked or expired")
    end

    it "refuses a revoked token" do
      api_token.revoke!
      call_tool
      expect_unauthorized("invalid, revoked or expired")
    end

    it "refuses an expired token" do
      api_token.update!(expires_at: 1.day.from_now)
      travel_to(2.days.from_now) { call_tool }
      expect_unauthorized
    end

    it "refuses a token without read access" do
      api_token.update!(scopes: ["write"])
      call_tool
      expect(response).to have_http_status(:forbidden)
      expect(response.headers["WWW-Authenticate"]).to include("insufficient_scope")
    end

    it "refuses a user who has been removed from their unit" do
      api_token
      user.update!(unit: nil)
      call_tool
      expect_unauthorized("not assigned to a unit")
    end

    context "when MCP is not yet enabled for everyone" do
      before { user.update!(admin: false) }

      it "refuses a user who is not a site admin" do
        call_tool
        expect_unauthorized("not enabled for your account yet")
      end

      it "allows them once MCP_ENABLED is set" do
        allow(::EdifyConfig).to receive(:mcp_enabled_for_everyone?).and_return(true)
        call_tool
        expect(tool_result["isError"]).to be(false)
      end
    end

    it "refuses a request for another host, against DNS rebinding" do
      host! "attacker.example"
      call_tool
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "rate limiting" do
    it "answers 429 once a token passes the limit" do
      allow(Rails.cache).to receive(:increment).and_return(McpController::REQUESTS_PER_MINUTE + 1)

      call_tool

      expect(response).to have_http_status(:too_many_requests)
      expect(json.dig("error", "message")).to include("Too many requests")
    end
  end
end
