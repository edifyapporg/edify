require "rails_helper"

RSpec.describe "Members" do
  let(:user) { users(:sunny_bishopric) }
  let(:member) { members(:bartell_randal) }

  before { login_as user, scope: :user }

  describe "GET /members/:id/edit" do
    it "explains that only the birth year is kept, and that a blank birthdate keeps it" do
      get edit_member_path(member)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Edify keeps only the birth year.", "Leave blank to keep 1997.")
    end
  end

  describe "GET /members/new" do
    it "asks for a birthdate without mentioning a year to keep" do
      get new_member_path

      expect(response.body).to include("Edify keeps only the birth year.")
      expect(response.body).not_to include("Leave blank to keep")
    end
  end

  describe "PATCH /members/:id" do
    def update(birthdate)
      patch member_path(member), params: { member: { name: member.name, gender: member.gender, birthdate: birthdate } }
    end

    it "keeps the birth year when the birthdate is left blank" do
      update("")
      expect(member.reload.birth_year).to eq(1997)
    end

    it "stores only the year of a new birthdate" do
      update("04/02/1996")
      expect(member.reload.birth_year).to eq(1996)
    end
  end
end
