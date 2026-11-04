require "rails_helper"

RSpec.describe "Units" do
  # Barrows, Kenneth spoke and "The Morning Breaks #1" was sung on 2022-04-10, both in
  # Sunny Hills (unit 1). Pleasant Forest (unit 2) has neither.
  let(:sunny_hills) { units(:sunny_hills) }
  let(:speaker_name) { "Barrows, Kenneth" }
  let(:song_title) { "The Morning Breaks #1" }
  let(:date) { "2022-05-15" }

  let(:turbo_stream) { { "Accept" => "text/vnd.turbo-stream.html" } }

  describe "GET /unit/speaker_last_spoke" do
    def make_request(params = {})
      get speaker_last_spoke_unit_path, params: { name: speaker_name, date: date }.merge(params), headers: turbo_stream
    end

    context "when the user is in the bishopric of the unit where the speaker spoke" do
      before { login_as users(:sunny_bishopric), scope: :user }

      it "reports when the speaker last spoke" do
        make_request
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Previously spoke about 1 month before this meeting")
      end
    end

    context "when the user is in the bishopric of a different unit" do
      before { login_as users(:pleasant_one), scope: :user }

      it "searches only the user's own unit" do
        make_request
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("No record of this member having spoken before this meeting")
      end

      it "ignores a unit id supplied in the request" do
        make_request(id: sunny_hills.id, unit_id: sunny_hills.id)
        expect(response.body).to include("No record of this member having spoken before this meeting")
        expect(response.body).not_to include("Previously spoke")
      end
    end

    context "when the user is not in the bishopric" do
      before { login_as users(:sunny_music), scope: :user }

      it "refuses the request" do
        make_request
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to be_present
      end
    end

    context "when the user is not assigned to a unit" do
      before { login_as users(:unassigned), scope: :user }

      it "refuses the request without an error" do
        make_request
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to be_present
      end
    end

    context "when no one is signed in" do
      it "sends the user to sign in" do
        make_request
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "GET /unit/song_last_sung" do
    def make_request(params = {})
      get song_last_sung_unit_path, params: { title: song_title, date: date }.merge(params), headers: turbo_stream
    end

    context "when the user is a music editor in the unit where the song was sung" do
      before { login_as users(:sunny_music), scope: :user }

      it "reports when the song was last sung" do
        make_request
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Previously sung about 1 month before this meeting")
      end
    end

    context "when the user is a music editor in a different unit" do
      before { login_as users(:pleasant_one), scope: :user }

      it "searches only the user's own unit" do
        make_request
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("No record of this song found before this meeting")
      end

      it "ignores a unit id supplied in the request" do
        make_request(id: sunny_hills.id, unit_id: sunny_hills.id)
        expect(response.body).to include("No record of this song found before this meeting")
        expect(response.body).not_to include("Previously sung")
      end
    end

    context "when the user cannot edit music" do
      before { login_as users(:sunny_program), scope: :user }

      it "refuses the request" do
        make_request
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to be_present
      end
    end

    context "when the user is not assigned to a unit" do
      before { login_as users(:unassigned), scope: :user }

      it "refuses the request without an error" do
        make_request
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to be_present
      end
    end
  end

  describe "routes that took a unit id" do
    before { login_as users(:sunny_bishopric), scope: :user }

    %w[
      /units/1/speaker_last_spoke
      /units/1/song_last_sung
      /units/1/edit
    ].each do |path|
      it "no longer routes GET #{path}" do
        expect { get path }.to raise_error(ActionController::RoutingError)
      end
    end

    it "no longer routes PATCH /units/1" do
      expect { patch "/units/1", params: { unit: { name: "Renamed" } } }.to raise_error(ActionController::RoutingError)
    end
  end
end
