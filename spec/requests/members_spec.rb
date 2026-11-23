require "rails_helper"

RSpec.describe "Members" do
  let(:user) { users(:sunny_bishopric) }
  let(:member) { members(:bartell_randal) }

  before { login_as user, scope: :user }

  describe "GET /members/:id/edit" do
    it "shows the stored birth year" do
      get edit_member_path(member)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('name="member[birth_year]"', 'value="1997"')
      expect(response.body).not_to include("member[birthdate]")
    end
  end

  describe "GET /members/new" do
    it "asks for a birth year" do
      get new_member_path

      expect(response.body).to include('name="member[birth_year]"')
      expect(response.body).not_to include("member[birthdate]")
    end
  end

  describe "POST /members" do
    def create_member(birth_year)
      post members_path, params: { member: { name: "Newcomer, Nia", gender: "female", birth_year: birth_year } }
    end

    it "adds a member who turns eight this year" do
      expect { create_member(Date.current.year - 8) }.to change(Member, :count).by(1)
      expect(Member.find_by(name: "Newcomer, Nia").birth_year).to eq(Date.current.year - 8)
    end

    it "refuses a member who turns seven this year" do
      expect { create_member(Date.current.year - 7) }.not_to change(Member, :count)
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Birth year member is not old enough")
    end
  end

  describe "PATCH /members/:id" do
    def update(birth_year)
      patch member_path(member), params: { member: { name: member.name, gender: member.gender, birth_year: birth_year } }
    end

    it "changes the birth year" do
      update("1996")
      expect(member.reload.birth_year).to eq(1996)
    end

    it "refuses a blank or future birth year" do
      update("")
      expect(response).to have_http_status(:unprocessable_content)

      update((Date.current.year + 1).to_s)
      expect(response).to have_http_status(:unprocessable_content)
      expect(member.reload.birth_year).to eq(1997)
    end
  end
end
