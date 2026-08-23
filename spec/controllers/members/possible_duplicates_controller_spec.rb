require "rails_helper"

RSpec.describe Members::PossibleDuplicatesController, type: :controller do
  include Devise::Test::ControllerHelpers

  render_views

  let(:unit) { units(:sunny_hills) }

  before { unit.update!(last_synced_on: Date.current) }

  context "with LCR access" do
    let(:user) { users(:sunny_bishopric) }

    before { sign_in user }

    describe "GET #index" do
      it "returns a successful response" do
        get :index
        expect(response).to be_successful
      end

      it "renders a surfaced duplicate pair" do
        unit.members.create!(name: "Renderme, Kate", gender: :female, birthdate: "1992-02-02", synced_on: Date.current)
        unit.members.create!(name: "Renderme, Kate Marie", gender: :female, birthdate: "1992-02-02", synced_on: Date.current)

        get :index

        expect(response.body).to include("Renderme, Kate Marie")
        expect(response.body).to include("Merge")
      end
    end

    describe "GET #summary" do
      it "shows a review link when possible duplicates exist" do
        unit.members.create!(name: "Summ, Ary", gender: :female, birthdate: "1993-03-03", synced_on: Date.current)
        unit.members.create!(name: "Summ, Ary Jean", gender: :female, birthdate: "1993-03-03", synced_on: Date.current)

        get :summary

        expect(response.body).to include(members_possible_duplicates_path)
        expect(response.body).to include("possible duplicate")
      end

      it "shows nothing when there are no possible duplicates" do
        get :summary
        expect(response.body).not_to include("possible duplicate")
      end
    end

    describe "PUT #merge" do
      let(:keep) { unit.members.create!(name: "Keeper, Sam", gender: :male, birthdate: "1990-01-01", synced_on: Date.current) }
      let(:remove) { unit.members.create!(name: "Keeper, Samuel", gender: :male, birthdate: "1990-01-01", synced_on: 1.day.ago) }

      it "merges the pair and deletes the removed member" do
        put :merge, params: { keep_id: keep.id, remove_id: remove.id }

        expect(::Member.exists?(remove.id)).to be(false)
        expect(response).to redirect_to(members_possible_duplicates_path)
      end
    end

    describe "POST #dismiss" do
      let(:member_a) { unit.members.create!(name: "Dodge, Kim", gender: :female, birthdate: "1991-01-01", synced_on: Date.current) }
      let(:member_b) { unit.members.create!(name: "Dodge, Kimberly", gender: :female, birthdate: "1991-01-01", synced_on: Date.current) }

      it "records a dismissal for the pair" do
        expect { post :dismiss, params: { member_a_id: member_a.id, member_b_id: member_b.id } }
          .to change(::Members::DuplicateDismissal, :count).by(1)
      end
    end
  end

  context "without LCR access" do
    let(:user) { users(:sunny_music) }

    before { sign_in user }

    it "redirects away from the index" do
      get :index
      expect(response).to redirect_to(root_path)
    end
  end
end
