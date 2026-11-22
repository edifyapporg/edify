require "rails_helper"

RSpec.describe "Settings API tokens" do
  let(:user) { users(:sunny_bishopric) }
  let(:other_user) { users(:pleasant_one) }

  def create_token(owner, name: "Existing token", **attributes)
    ::ApiToken.create!(user: owner, name: name, **attributes)
  end

  describe "GET /settings/api_tokens" do
    context "when the user is assigned to a unit" do
      before { login_as user, scope: :user }

      it "lists only the user's own tokens and never shows a plaintext token" do
        own = create_token(user, name: "My laptop")
        other = create_token(other_user, name: "Someone else's laptop")

        get settings_api_tokens_path

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("My laptop", "Active", ">Revoke<")
        expect(response.body).not_to include("Someone else&#39;s laptop")
        expect(response.body).not_to include(own.plaintext_token)
        expect(response.body).not_to include(other.plaintext_token)
      end

      it "shows revoked and expired tokens without a revoke button" do
        create_token(user, name: "Old token").revoke!
        create_token(user, name: "Short token", expires_at: 1.day.from_now)

        travel_to(2.days.from_now) { get settings_api_tokens_path }

        expect(response.body).to include("Revoked", "Expired")
        expect(response.body).not_to include(">Revoke<")
      end
    end

    context "when the user is not assigned to a unit" do
      before { login_as users(:unassigned), scope: :user }

      it "refuses access" do
        get settings_api_tokens_path
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq("Not authorized.")
      end
    end

    context "when no one is signed in" do
      it "sends the visitor to sign in" do
        get settings_api_tokens_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "POST /settings/api_tokens" do
    def make_request(name: "Claude Code", expires_in: "30 days")
      post settings_api_tokens_path, params: { api_token: { name: name, expires_in: expires_in } }
    end

    context "when the user is assigned to a unit" do
      before { login_as user, scope: :user }

      it "creates a read-only token and shows its plaintext once" do
        expect { make_request }.to change { user.api_tokens.count }.by(1)

        token = user.api_tokens.last
        plaintext = response.body[/edify_[1-9A-HJ-NP-Za-km-z]{32}/]
        expect(response).to have_http_status(:created)
        expect(token.name).to eq("Claude Code")
        expect(token.scopes).to eq(["read"])
        expect(plaintext).to be_present
        expect(::ApiToken.authenticate(plaintext)).to eq(token)

        get settings_api_tokens_path
        expect(response.body).not_to include(plaintext)
      end

      it "does not put the plaintext token in the flash" do
        make_request
        expect(flash.to_hash.values.join).not_to include("edify_")
      end

      it "sets the chosen expiry" do
        freeze_time do
          make_request(expires_in: "1 year")
          expect(user.api_tokens.last.expires_at).to eq(1.year.from_now)
        end
      end

      it "creates a token that never expires when asked" do
        make_request(expires_in: "Never")
        expect(user.api_tokens.last.expires_at).to be_nil
      end

      it "falls back to the default expiry for an unknown choice" do
        freeze_time do
          make_request(expires_in: "forever and ever")
          expect(user.api_tokens.last.expires_at).to eq(90.days.from_now)
        end
      end

      it "ignores attempts to set scopes or the owner" do
        post settings_api_tokens_path,
             params: { api_token: { name: "Sneaky", expires_in: "30 days", scopes: ["write"], user_id: other_user.id } }

        token = ::ApiToken.find_by(name: "Sneaky")
        expect(token.user).to eq(user)
        expect(token.scopes).to eq(["read"])
      end

      it "shows errors and creates nothing when the name is missing" do
        expect { make_request(name: "") }.not_to change(::ApiToken, :count)
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("Name can&#39;t be blank")
      end
    end

    context "when the user is not assigned to a unit" do
      before { login_as users(:unassigned), scope: :user }

      it "refuses and creates nothing" do
        expect { make_request }.not_to change(::ApiToken, :count)
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "PATCH /settings/api_tokens/:id/revoke" do
    context "when the token belongs to the user" do
      before { login_as user, scope: :user }

      it "revokes it" do
        token = create_token(user)

        patch revoke_settings_api_token_path(token)

        expect(response).to redirect_to(settings_api_tokens_path)
        expect(token.reload).to be_revoked
      end
    end

    context "when the token belongs to another user" do
      before { login_as user, scope: :user }

      it "cannot find it and leaves it active" do
        token = create_token(other_user)

        expect { patch revoke_settings_api_token_path(token) }.to raise_error(ActiveRecord::RecordNotFound)
        expect(token.reload).to be_active
      end
    end

    context "when the user is a site admin" do
      before { login_as users(:admin), scope: :user }

      it "still cannot revoke another user's token" do
        token = create_token(user)

        expect { patch revoke_settings_api_token_path(token) }.to raise_error(ActiveRecord::RecordNotFound)
        expect(token.reload).to be_active
      end
    end

    context "when the user has since been removed from their unit" do
      it "still lets them revoke their own token" do
        token = create_token(user)
        user.update!(unit: nil)
        login_as user, scope: :user

        patch revoke_settings_api_token_path(token)

        expect(token.reload).to be_revoked
      end
    end
  end
end
