require "rails_helper"

RSpec.describe "API v1 songs" do
  let(:user) { users(:sunny_bishopric) }
  let(:unit) { units(:sunny_hills) }
  let(:api_token) { ::ApiToken.create!(user: user, name: "Spec token") }
  let(:headers) { { "Authorization" => "Bearer #{api_token.plaintext_token}" } }
  let(:json) { response.parsed_body }

  around { |example| travel_to(Date.new(2026, 6, 15)) { example.run } }

  before do
    sing("Come, Follow Me #116", on: Date.new(2026, 6, 7))
    sing("Come, Follow Me #116", on: Date.new(2026, 5, 3))
    sing("Abide with Me #166", on: Date.new(2026, 5, 31))
    sing("Other Ward Hymn", on: Date.new(2026, 6, 7), in_unit: units(:pleasant_forest))
  end

  def sing(title, on:, in_unit: unit, type: :opening_hymn)
    meeting = in_unit.meetings.find_or_create_by!(date: on) { |m| m.meeting_type = :sacrament_meeting }
    meeting.songs.create!(title: title, song_type: type)
  end

  def make_request(params = {}, request_headers = headers)
    get api_v1_songs_recent_path, params: params, headers: request_headers
  end

  describe "GET /api/v1/songs/recent" do
    it "lists the unit's hymns from the last 12 weeks, most sung first" do
      make_request

      expect(response).to have_http_status(:ok)
      expect(json).to eq(
        "weeks" => 12,
        "song_type" => nil,
        "since" => "2026-03-23",
        "songs" => [
          { "title" => "Come, Follow Me #116", "times_sung" => 2, "last_sung" => "2026-06-07",
            "song_types" => ["opening_hymn"] },
          { "title" => "Abide with Me #166", "times_sung" => 1, "last_sung" => "2026-05-31",
            "song_types" => ["opening_hymn"] },
        ]
      )
    end

    it "uses the weeks and limit asked for" do
      make_request(weeks: 4, limit: 1)

      expect(json).to include("weeks" => 4, "since" => "2026-05-18")
      expect(json["songs"].pluck("title")).to eq(["Come, Follow Me #116"])
    end

    it "counts only the song type asked for" do
      sing("I Stand All Amazed #193", on: Date.new(2026, 6, 14), type: :sacrament_hymn)

      make_request(song_type: "sacrament_hymn")

      expect(json).to include("song_type" => "sacrament_hymn")
      expect(json["songs"]).to eq([{ "title" => "I Stand All Amazed #193", "times_sung" => 1,
                                     "last_sung" => "2026-06-14", "song_types" => ["sacrament_hymn"] }])
    end

    [{ song_type: "prelude" }, { song_type: "Sacrament_Hymn" }, { song_type: "" }, { song_type: ["sacrament_hymn"] }]
      .each do |params|
      it "rejects the song type #{params[:song_type].inspect}" do
        make_request(params)
        expect(response).to have_http_status(:unprocessable_content)
        expect(json["error"]["message"]).to start_with("song_type must be one of opening_hymn, sacrament_hymn")
      end
    end

    it "ignores a unit id supplied in the request" do
      make_request(unit_id: units(:pleasant_forest).id)
      expect(json["songs"].pluck("title")).not_to include("Other Ward Hymn")
    end

    [{ weeks: 0 }, { weeks: 105 }, { weeks: "twelve" }, { weeks: "010.5" }, { limit: 0 }, { limit: 201 }].each do |params|
      it "rejects #{params}" do
        make_request(params)
        expect(response).to have_http_status(:unprocessable_content)
        expect(json["error"]["code"]).to eq("invalid_request")
      end
    end

    %i[sunny_clerk sunny_music sunny_program].each do |role_user|
      context "with #{role_user}" do
        let(:user) { users(role_user) }

        it "is allowed, since every role sees the songs on the meetings page" do
          make_request
          expect(response).to have_http_status(:ok)
        end
      end
    end

    context "with a user from another unit" do
      let(:user) { users(:pleasant_one) }

      it "sees only their own unit's songs" do
        make_request
        expect(json["songs"].pluck("title")).to eq(["Other Ward Hymn"])
      end
    end

    context "without a token" do
      it "is unauthorized" do
        make_request({}, {})
        expect(response).to have_http_status(:unauthorized)
        expect(json["error"]["code"]).to eq("invalid_token")
      end
    end

    context "with a revoked token" do
      it "is unauthorized" do
        api_token.revoke!
        make_request
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
