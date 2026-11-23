require "rails_helper"

RSpec.describe "API v1 talks" do
  let(:user) { users(:sunny_bishopric) }
  let(:unit) { units(:sunny_hills) }
  let(:api_token) { ::ApiToken.create!(user: user, name: "Spec token") }
  let(:headers) { { "Authorization" => "Bearer #{api_token.plaintext_token}" } }
  let(:json) { response.parsed_body }

  def talk(on:, speaker:, purpose: nil, topic: nil, in_unit: unit, **attributes)
    meeting = in_unit.meetings.find_or_create_by!(date: on) { |m| m.meeting_type = :sacrament_meeting }
    meeting.talks.create!(speaker_name: speaker, purpose: purpose, topic: topic, **attributes)
  end

  def make_request(params = {}, request_headers = headers)
    get api_v1_talks_path, params: params, headers: request_headers
  end

  def speakers
    json["talks"].pluck("speaker")
  end

  before do
    talk(on: Date.new(2027, 1, 10), speaker: "Zz, Jane Smith", purpose: "Departing Missionary", topic: "Faith")
    talk(on: Date.new(2027, 1, 10), speaker: "Zz, Amy Jones")
    talk(on: Date.new(2027, 2, 14), speaker: "Zz, John Smith", purpose: "Stake Representative", topic: "Hope",
         member: members(:bartell_randal))
    talk(on: Date.new(2027, 3, 7), speaker: "Zz, Jane Smith", topic: "Charity")
    talk(on: Date.new(2027, 3, 7), speaker: "Zz, Other Ward", in_unit: units(:pleasant_forest))
  end

  describe "GET /api/v1/talks" do
    it "lists the unit's talks newest first, with date, speaker, purpose and topic" do
      make_request(from: "2027-01-01")

      expect(response).to have_http_status(:ok)
      expect(json).to eq(
        "speaker" => nil, "purpose" => nil, "from" => "2027-01-01", "to" => nil, "limit" => 50,
        "talks" => [
          { "date" => "2027-03-07", "speaker" => "Zz, Jane Smith", "purpose" => nil, "topic" => "Charity" },
          { "date" => "2027-02-14", "speaker" => "Zz, John Smith", "purpose" => "Stake Representative",
            "topic" => "Hope" },
          { "date" => "2027-01-10", "speaker" => "Zz, Jane Smith", "purpose" => "Departing Missionary",
            "topic" => "Faith" },
          { "date" => "2027-01-10", "speaker" => "Zz, Amy Jones", "purpose" => nil, "topic" => nil },
        ]
      )
    end

    it "filters by every word of the speaker's name" do
      make_request(speaker: "smith jane", from: "2027-01-01")
      expect(json["talks"].pluck("date")).to eq(%w[2027-03-07 2027-01-10])
    end

    it "filters by part of the purpose, ignoring case" do
      make_request(purpose: "missionary", from: "2027-01-01")
      expect(speakers).to eq(["Zz, Jane Smith"])
    end

    it "filters by an inclusive date range" do
      make_request(from: "2027-01-10", to: "2027-02-14")
      expect(json["talks"].pluck("date")).to eq(%w[2027-02-14 2027-01-10 2027-01-10])
    end

    it "combines filters and the limit, echoing each" do
      make_request(speaker: "  jane   smith ", from: "2027-01-01", limit: 1)
      expect(json).to include("speaker" => "jane smith", "limit" => 1)
      expect(json["talks"].pluck("date")).to eq(["2027-03-07"])
    end

    it "never includes the linked member or their details" do
      make_request(from: "2027-01-01")
      expect(response.body).not_to include("member", members(:bartell_randal).phone_number.to_s, "@")
    end

    it "searches only the user's own unit, whatever unit id is supplied" do
      make_request(from: "2027-01-01", unit_id: units(:pleasant_forest).id)
      expect(speakers).not_to include("Zz, Other Ward")
    end

    [
      [{ speaker: "z" }, "speaker must be from 2 to 100 characters."],
      [{ purpose: "x" * 101 }, "purpose must be from 2 to 100 characters."],
      [{ speaker: ["smith"] }, "speaker must be from 2 to 100 characters."],
      [{ from: "1/1/2027" }, "from must be a date written as YYYY-MM-DD."],
      [{ to: "2027-02-30" }, "to must be a date written as YYYY-MM-DD."],
      [{ from: "2027-03-01", to: "2027-02-01" }, "to must not be before from."],
      [{ limit: 0 }, "limit must be a whole number from 1 to 200."],
    ].each do |params, message|
      it "rejects #{params.transform_values { it.is_a?(String) && it.length > 20 ? "#{it[0, 5]}..." : it }}" do
        make_request(params)
        expect(response).to have_http_status(:unprocessable_content)
        expect(json["error"]).to eq("code" => "invalid_request", "message" => message)
      end
    end

    context "with a clerk" do
      let(:user) { users(:sunny_clerk) }

      it "is allowed, as on the talks page" do
        make_request
        expect(response).to have_http_status(:ok)
      end
    end

    %i[sunny_music sunny_program].each do |role_user|
      context "with #{role_user}, who cannot see the talks page" do
        let(:user) { users(role_user) }

        it "is forbidden" do
          make_request
          expect(response).to have_http_status(:forbidden)
        end
      end
    end

    context "without a token" do
      it "is unauthorized" do
        make_request({}, {})
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
