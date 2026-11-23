require "rails_helper"

RSpec.describe "API v1 meetings" do
  let(:user) { users(:sunny_bishopric) }
  let(:unit) { units(:sunny_hills) }
  let(:api_token) { ::ApiToken.create!(user: user, name: "Spec token") }
  let(:headers) { { "Authorization" => "Bearer #{api_token.plaintext_token}" } }
  let(:json) { response.parsed_body }
  # Every example works against this meeting of the unit.
  before do
    unit.meetings.create!(
      date: Date.new(2026, 11, 8), meeting_type: :sacrament_meeting,
      presider_name: "Bishop Young", conductor_name: "Brother Ruiz", chorister_name: "Sister Lee",
      organist_name: "Brother Park", opening_prayer_name: "Sister Hale", closing_prayer_name: "Brother Diaz"
    ).tap do |m|
      m.talks.create!(speaker_name: "Smith, Jane", purpose: "Youth Speaker", topic: "Gratitude")
      m.talks.create!(speaker_name: "Jones, Sam", topic: "Faith", member: members(:bartell_randal))
      m.songs.create!(song_type: :closing_hymn, title: "Abide with Me #166")
      m.songs.create!(song_type: :opening_hymn, title: "Come, Follow Me #116")
    end
  end

  around { |example| travel_to(Date.new(2026, 11, 1)) { example.run } }

  describe "GET /api/v1/meetings" do
    before do
      unit.meetings.create!(date: Date.new(2026, 10, 25), meeting_type: :sacrament_meeting)
      unit.meetings.create!(date: Date.new(2027, 3, 7), meeting_type: :stake_conference)
      units(:pleasant_forest).meetings.create!(date: Date.new(2026, 11, 8), meeting_type: :sacrament_meeting)
    end

    def make_request(params = {})
      get api_v1_meetings_path, params: params, headers: headers
    end

    it "lists the unit's meetings from today through 84 days, with their speakers" do
      make_request

      expect(response).to have_http_status(:ok)
      expect(json).to eq(
        "from" => "2026-11-01",
        "to" => "2027-01-24",
        "meetings" => [
          { "date" => "2026-11-08", "meeting_type" => "sacrament_meeting", "speakers" => ["Smith, Jane", "Jones, Sam"] },
        ]
      )
    end

    it "uses the range asked for" do
      make_request(from: "2026-10-01", to: "2027-03-31")
      expect(json["meetings"].pluck("date")).to eq(%w[2026-10-25 2026-11-08 2027-03-07])
    end

    it "defaults the end to 84 days after a given start" do
      make_request(from: "2027-01-01")
      expect(json).to include("from" => "2027-01-01", "to" => "2027-03-26")
      expect(json["meetings"].pluck("date")).to eq(["2027-03-07"])
    end

    [
      [{ from: "11/1/2026" }, "from must be a date"],
      [{ from: "2026-02-30" }, "from must be a date"],
      [{ to: "soon" }, "to must be a date"],
      [{ from: "2026-11-01", to: "2026-10-01" }, "to must not be before from"],
      [{ from: "2026-01-01", to: "2027-01-03" }, "at most 366 days"],
    ].each do |params, message|
      it "rejects #{params}" do
        make_request(params)
        expect(response).to have_http_status(:unprocessable_content)
        expect(json["error"]).to include("code" => "invalid_request", "message" => a_string_including(message))
      end
    end
  end

  describe "GET /api/v1/meetings/:date" do
    def make_request(date)
      get api_v1_meeting_path(date), headers: headers
    end

    it "returns the meeting with its contributors, talks in order and songs in program order" do
      make_request("2026-11-08")

      expect(response).to have_http_status(:ok)
      expect(json).to eq(
        "date" => "2026-11-08",
        "meeting_type" => "sacrament_meeting",
        "contributors" => {
          "presider" => "Bishop Young", "conductor" => "Brother Ruiz", "chorister" => "Sister Lee",
          "organist" => "Brother Park", "opening_prayer" => "Sister Hale", "closing_prayer" => "Brother Diaz"
        },
        "talks" => [
          { "position" => 1, "speaker" => "Smith, Jane", "purpose" => "Youth Speaker", "topic" => "Gratitude" },
          { "position" => 2, "speaker" => "Jones, Sam", "purpose" => nil, "topic" => "Faith" },
        ],
        "songs" => [
          { "song_type" => "opening_hymn", "title" => "Come, Follow Me #116" },
          { "song_type" => "closing_hymn", "title" => "Abide with Me #166" },
        ]
      )
    end

    it "never includes member ids, the scheduler, or a linked member's contact details" do
      make_request("2026-11-08")
      expect(response.body).not_to include("member", "scheduler", "@", members(:bartell_randal).phone_number)
    end

    it "is not found for a date with no meeting" do
      make_request("2026-11-15")
      expect(response).to have_http_status(:not_found)
      expect(json["error"]["code"]).to eq("not_found")
    end

    it "rejects a date not written as YYYY-MM-DD" do
      make_request("11-8-2026")
      expect(response).to have_http_status(:unprocessable_content)
    end

    context "with a user from another unit" do
      let(:user) { users(:pleasant_one) }

      it "finds only their own unit's meeting on that date" do
        units(:pleasant_forest).meetings.create!(date: Date.new(2026, 11, 8), meeting_type: :sacrament_meeting)

        make_request("2026-11-08")

        expect(response).to have_http_status(:ok)
        expect(json).to include("talks" => [], "songs" => [])
      end

      it "is not found where only another unit has a meeting" do
        unit.meetings.create!(date: Date.new(2026, 11, 22), meeting_type: :sacrament_meeting)
        make_request("2026-11-22")
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  %i[sunny_clerk sunny_music sunny_program].each do |role_user|
    context "with #{role_user}" do
      let(:user) { users(role_user) }

      it "may list and show meetings, as on the meetings page" do
        get api_v1_meetings_path, headers: headers
        expect(response).to have_http_status(:ok)
        get api_v1_meeting_path("2026-11-08"), headers: headers
        expect(response).to have_http_status(:ok)
      end
    end
  end

  context "without a token" do
    it "is unauthorized" do
      get api_v1_meetings_path
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
