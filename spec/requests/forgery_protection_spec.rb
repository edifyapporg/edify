require "rails_helper"

# devise-jwt once let a JSON client sign in without a CSRF token, get a JWT back, and call the JSON upsert actions,
# which also skipped CSRF. With it removed (#318), JSON sign-in issues no token and the upserts accept only requests
# carrying the page's CSRF token, like every other form in the app. Forgery protection is off in the test
# environment by default, so these examples turn it on.
RSpec.describe "Forgery protection" do
  around do |example|
    original = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    example.run
  ensure
    ActionController::Base.allow_forgery_protection = original
  end

  let(:user) { users(:sunny_bishopric) }
  let(:meeting) { meetings(:meeting_1) }
  let(:json) { { "Accept" => "application/json" } }

  def csrf_token_from_page
    get members_path
    response.body[/<meta name="csrf-token" content="([^"]+)"/, 1]
  end

  describe "JSON sign-in" do
    it "is refused without a CSRF token and returns no token" do
      expect do
        post user_session_path(format: :json), params: { user: { email: user.email, password: "password" } }
      end.to raise_error(ActionController::InvalidAuthenticityToken)
    end
  end

  describe "the JSON upsert actions" do
    before { login_as user, scope: :user }

    it "refuses a talk upsert without a CSRF token" do
      expect do
        post upsert_meeting_talks_path(meeting, format: :json), params: { talk: { speaker_name: "Forged Speaker" } }
      end.to raise_error(ActionController::InvalidAuthenticityToken)
      expect(meeting.talks.where(speaker_name: "Forged Speaker")).to be_empty
    end

    it "accepts a talk upsert carrying the page's CSRF token" do
      token = csrf_token_from_page
      expect(token).to be_present

      post upsert_meeting_talks_path(meeting, format: :json),
           params: { talk: { speaker_name: "Real Speaker" } },
           headers: json.merge("X-CSRF-Token" => token)

      expect(response).to have_http_status(:created)
      expect(meeting.talks.where(speaker_name: "Real Speaker")).to exist
    end

    it "refuses a meeting upsert without a CSRF token" do
      expect do
        post upsert_meetings_path(format: :json), params: { meeting: { date: "2030-01-05" } }
      end.to raise_error(ActionController::InvalidAuthenticityToken)
    end

    it "refuses a member upsert without a CSRF token" do
      expect do
        post upsert_members_path(format: :json), params: { member: { name: "Forged, Member" } }
      end.to raise_error(ActionController::InvalidAuthenticityToken)
      expect(::Member.where(name: "Forged, Member")).to be_empty
    end
  end
end
