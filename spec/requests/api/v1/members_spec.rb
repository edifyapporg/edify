require "rails_helper"

RSpec.describe "API v1 members" do
  let(:user) { users(:sunny_bishopric) }
  let(:unit) { units(:sunny_hills) }
  let(:api_token) { ::ApiToken.create!(user: user, name: "Spec token") }
  let(:headers) { { "Authorization" => "Bearer #{api_token.plaintext_token}" } }
  let(:json) { response.parsed_body }

  # Members are created as present in the unit's most recent import, so "hide moved members" (on by default) keeps
  # them visible.
  def create_member(name, in_unit: unit, **attributes)
    in_unit.members.create!(name: name, gender: :female, birthdate: "1980-01-01", synced_on: in_unit.last_synced_on,
                            phone_number: "303-555-0100", email: "member@example.com", **attributes)
  end

  def make_request(params = { q: "zzsmith" }, request_headers = headers)
    get api_v1_members_path, params: params, headers: request_headers
  end

  before do
    create_member("Zzsmith, John", gender: :male)
    create_member("Zzsmith, Ann", birthdate: 15.years.ago.to_date)
    create_member("Zzother, Pat")
  end

  describe "GET /api/v1/members" do
    it "finds the unit's members by name, alphabetically, with name, gender and age group only" do
      make_request

      expect(response).to have_http_status(:ok)
      expect(json).to eq(
        "query" => "zzsmith",
        "limit" => 25,
        "members" => [
          { "name" => "Zzsmith, Ann", "gender" => "female", "group" => "youth" },
          { "name" => "Zzsmith, John", "gender" => "male", "group" => "adult" },
        ]
      )
    end

    it "matches every word in any order" do
      make_request(q: "john zzsmith")
      expect(json["members"].pluck("name")).to eq(["Zzsmith, John"])
    end

    it "never includes contact details, birthdates or ids" do
      make_request
      expect(response.body).not_to include("303-555-0100", "@", "1980-01-01", "birthdate", "\"id\"")
    end

    it "uses the limit asked for" do
      make_request(q: "zzsmith", limit: 1)
      expect(json["members"].pluck("name")).to eq(["Zzsmith, Ann"])
    end

    it "leaves out moved members when the user hides them, as the members page does" do
      create_member("Zzsmith, Moved", synced_on: unit.last_synced_on - 1.month)

      make_request

      expect(json["members"].pluck("name")).not_to include("Zzsmith, Moved")
    end

    it "searches only the user's own unit, whatever unit id is supplied" do
      create_member("Zzsmith, Other Ward", in_unit: units(:pleasant_forest))

      make_request(q: "zzsmith", unit_id: units(:pleasant_forest).id)

      expect(json["members"].pluck("name")).not_to include("Zzsmith, Other Ward")
    end

    [{}, { q: "" }, { q: "z" }, { q: "z" * 101 }, { q: ["zzsmith"] }, { q: "zzsmith", limit: 0 },
     { q: "zzsmith", limit: 101 },].each do |params|
      it "rejects #{params.transform_values { it.is_a?(String) && it.length > 20 ? "#{it[0, 5]}..." : it }}" do
        make_request(params)
        expect(response).to have_http_status(:unprocessable_content)
        expect(json["error"]["code"]).to eq("invalid_request")
      end
    end

    context "with a clerk" do
      let(:user) { users(:sunny_clerk) }

      it "is allowed, as on the members page" do
        make_request
        expect(response).to have_http_status(:ok)
      end
    end

    %i[sunny_music sunny_program].each do |role_user|
      context "with #{role_user}, who cannot see the members page" do
        let(:user) { users(role_user) }

        it "is forbidden" do
          make_request
          expect(response).to have_http_status(:forbidden)
          expect(json["error"]["code"]).to eq("forbidden")
        end
      end
    end

    context "without a token" do
      it "is unauthorized" do
        make_request({ q: "zzsmith" }, {})
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
