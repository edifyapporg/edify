require "rails_helper"

RSpec.describe "API v1 speakers" do
  let(:user) { users(:sunny_bishopric) }
  let(:unit) { units(:sunny_hills) }
  let(:api_token) { ::ApiToken.create!(user: user, name: "Spec token") }
  let(:headers) { { "Authorization" => "Bearer #{api_token.plaintext_token}" } }
  let(:json) { response.parsed_body }
  let!(:never_spoke) { create_member("Zz, Never Spoke") }
  let!(:recent_speaker) do
    create_member("Zz, Recent Speaker").tap do |member|
      meeting = unit.meetings.create!(date: 6.weeks.ago.to_date, meeting_type: :sacrament_meeting)
      meeting.talks.create!(speaker_name: member.name, member: member)
    end
  end

  # Members are created as present in their unit's most recent import, so "hide moved members" (on by default)
  # does not hide them.
  def create_member(name, in_unit: unit, **attributes)
    in_unit.members.create!(name: name, gender: :female, birthdate: "1980-01-01", synced_on: in_unit.last_synced_on,
                            **attributes)
  end

  def make_request(params = {}, request_headers = headers)
    get api_v1_speakers_stale_path, params: params, headers: request_headers
  end

  def speaker_names
    json["speakers"].pluck("name")
  end

  describe "GET /api/v1/speakers/stale" do
    context "with a valid token for a bishopric member" do
      it "lists the unit's members who have not spoken in a year, with name, gender, group and date only" do
        freeze_time do
          make_request

          expect(response).to have_http_status(:ok)
          expect(json["months"]).to eq(12)
          expect(json["group"]).to be_nil
          expect(json["spoken_before"]).to eq(12.months.ago.to_date.iso8601)
          expect(json["speakers"].map(&:keys).uniq).to eq([%w[name gender group last_talk_date]])
          expect(json["speakers"]).to include("name" => never_spoke.name, "gender" => "female", "group" => "adult",
                                              "last_talk_date" => nil)
          expect(speaker_names).to include(never_spoke.name)
          expect(speaker_names).not_to include(recent_speaker.name)
        end
      end

      it "never includes contact details, notes, ages or birthdates" do
        make_request(limit: 200)
        expect(response.body).not_to include("@", "phone", "email", "note", "birthdate", "age\"")
        expect(response.body).not_to include(never_spoke.birthdate.iso8601)
      end

      it "uses the months asked for" do
        make_request(months: 1, limit: 200)
        expect(json["months"]).to eq(1)
        expect(speaker_names).to include(recent_speaker.name)
      end

      it "returns at most the limit" do
        make_request(limit: 1)
        expect(json["speakers"].length).to eq(1)
      end

      it "records when the token was used" do
        expect { make_request }.to change { api_token.reload.last_used_at }.from(nil)
      end

      it "ignores a unit id supplied in the request" do
        other_member = create_member("Zz, Other Ward", in_unit: units(:pleasant_forest))
        make_request(unit_id: units(:pleasant_forest).id, limit: 200)
        expect(speaker_names).not_to include(other_member.name)
        expect(speaker_names).to include(never_spoke.name)
      end

      context "with members in each age group" do
        let!(:primary_child) { create_member("Zz, Primary Child", birthdate: 9.years.ago.to_date) }
        let!(:youth) { create_member("Zz, Youth Member", birthdate: 15.years.ago.to_date, gender: :male) }

        it "labels each speaker's group" do
          make_request(limit: 200)
          groups = json["speakers"].to_h { [it["name"], it["group"]] }
          expect(groups).to include(primary_child.name => "primary", youth.name => "youth", never_spoke.name => "adult")
        end

        { "primary" => "Zz, Primary Child", "youth" => "Zz, Youth Member", "adult" => "Zz, Never Spoke" }.each do |group, name|
          it "returns only #{group} members when asked" do
            make_request(group: group, limit: 200)
            expect(response).to have_http_status(:ok)
            expect(json["group"]).to eq(group)
            expect(json["speakers"].pluck("group").uniq).to eq([group])
            expect(speaker_names).to include(name)
          end
        end

        it "returns every group when none is given" do
          make_request(limit: 200)
          expect(json["speakers"].pluck("group").uniq).to contain_exactly("primary", "youth", "adult")
        end
      end

      [{ group: "child" }, { group: "" }, { group: "Youth" }, { group: ["youth"] }].each do |params|
        it "rejects the group #{params[:group].inspect}" do
          make_request(params)
          expect(response).to have_http_status(:unprocessable_content)
          expect(json["error"]).to eq("code" => "invalid_request",
                                      "message" => "group must be one of primary, youth, adult.")
        end
      end

      it "reads leading zeros as decimal, not octal" do
        make_request(months: "010")
        expect(response).to have_http_status(:ok)
        expect(json["months"]).to eq(10)
      end

      [
        { months: 0 }, { months: 121 }, { months: "twelve" }, { limit: 0 }, { limit: 201 },
        { months: "" }, { months: "12.5" }, { months: "-1" }, { months: " 12" }, { months: "0x10" }, { months: "1_2" },
        { months: ["12"] }, { months: { value: "12" } }, { limit: "99999999999999999999" },
      ].each do |params|
        it "rejects #{params}" do
          make_request(params)
          expect(response).to have_http_status(:unprocessable_content)
          expect(json["error"]["code"]).to eq("invalid_request")
          expect(json["error"]["message"]).to include("must be a whole number")
        end
      end
    end

    context "with a member missing from the unit's most recent import" do
      let!(:moved) { create_member("Zz, Moved Away", synced_on: unit.last_synced_on - 1.month) }

      it "leaves them out when the user hides moved members, as the members index does" do
        user.update!(hide_moved_members: true)
        make_request(limit: 200)
        expect(speaker_names).to include(never_spoke.name)
        expect(speaker_names).not_to include(moved.name)
      end

      it "includes them when the user shows moved members" do
        user.update!(hide_moved_members: false)
        make_request(limit: 200)
        expect(speaker_names).to include(never_spoke.name, moved.name)
      end
    end

    context "with a user from another unit" do
      let(:user) { users(:pleasant_one) }

      it "sees only their own unit's members" do
        make_request(limit: 200)
        expect(response).to have_http_status(:ok)
        expect(speaker_names).not_to include(never_spoke.name)
        expect(unit.members.pluck(:name) & speaker_names).to be_empty
      end
    end

    context "with a clerk" do
      let(:user) { users(:sunny_clerk) }

      it "allows access, as the members index does" do
        make_request
        expect(response).to have_http_status(:ok)
      end
    end

    context "with a role that cannot see the roster" do
      let(:user) { users(:sunny_music) }

      it "is forbidden" do
        make_request
        expect(response).to have_http_status(:forbidden)
        expect(json).to eq("error" => { "code" => "forbidden", "message" => "Your role does not have access to this." })
      end
    end

    context "without a token" do
      it "is unauthorized and says how to authenticate" do
        make_request({}, {})
        expect(response).to have_http_status(:unauthorized)
        expect(response.headers["WWW-Authenticate"]).to eq('Bearer realm="Edify"')
        expect(json["error"]["code"]).to eq("invalid_token")
      end
    end

    context "with a token that is not a bearer token" do
      it "is unauthorized" do
        make_request({}, { "Authorization" => api_token.plaintext_token })
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "with an unknown token" do
      it "is unauthorized" do
        make_request({}, { "Authorization" => "Bearer edify_notarealtoken" })
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "with a revoked token" do
      it "is unauthorized" do
        api_token.revoke!
        make_request
        expect(response).to have_http_status(:unauthorized)
        expect(json["error"]["code"]).to eq("invalid_token")
      end
    end

    context "with an expired token" do
      it "is unauthorized" do
        api_token.update!(expires_at: 1.day.from_now)
        travel_to(2.days.from_now) { make_request }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "with a token without read access" do
      it "is forbidden" do
        api_token.update!(scopes: ["write"])
        make_request
        expect(response).to have_http_status(:forbidden)
        expect(json["error"]["code"]).to eq("insufficient_scope")
      end
    end

    context "when the token's user has been removed from their unit" do
      it "is forbidden" do
        api_token
        user.update!(unit: nil)
        make_request
        expect(response).to have_http_status(:forbidden)
        expect(json["error"]["code"]).to eq("no_unit")
      end
    end

    context "when signed in with a browser session but no token" do
      it "is unauthorized" do
        login_as user, scope: :user
        make_request({}, {})
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "an unknown API path" do
    it "returns the API's not-found error" do
      get "/api/v1/nothing/here", headers: headers
      expect(response).to have_http_status(:not_found)
      expect(json).to eq("error" => { "code" => "not_found", "message" => "No such endpoint." })
    end
  end
end
