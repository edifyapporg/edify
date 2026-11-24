require "rails_helper"

RSpec.describe OauthSweepJob, type: :job do
  subject(:perform_job) { described_class.new.perform }

  let(:user) { users(:sunny_bishopric) }
  let(:claude) do
    ::OauthApplication.create!(name: "Claude", uid: "https://claude.ai/oauth/mcp-client-metadata", confidential: false,
                               redirect_uri: "https://claude.ai/api/mcp/auth_callback", scopes: "read",
                               metadata_fetched_at: Time.current)
  end

  def issue_token(created_at:, revoked_at: nil)
    ::OauthAccessToken.create!(application: claude, resource_owner_id: user.id, scopes: "read",
                               expires_in: 1.hour.to_i, use_refresh_token: true,
                               created_at: created_at, revoked_at: revoked_at)
  end

  def issue_grant(created_at:, revoked_at: nil)
    ::Doorkeeper::AccessGrant.create!(application: claude, resource_owner_id: user.id, scopes: "read",
                                      expires_in: 10.minutes.to_i, redirect_uri: claude.redirect_uri,
                                      code_challenge: "challenge", code_challenge_method: "S256",
                                      created_at: created_at, revoked_at: revoked_at)
  end

  it "enqueues the job" do
    expect { described_class.perform_later }.to have_enqueued_job(described_class)
  end

  describe "#perform" do
    it "keeps a token whose refresh token still works, though its access token has expired" do
      token = issue_token(created_at: 29.days.ago)

      perform_job

      expect(::OauthAccessToken.exists?(token.id)).to be(true)
    end

    it "deletes tokens past the refresh token lifetime, revoked or not" do
      expired = issue_token(created_at: 31.days.ago)
      revoked = issue_token(created_at: 31.days.ago, revoked_at: 30.days.ago)

      perform_job

      expect(::OauthAccessToken.where(id: [expired.id, revoked.id])).to be_empty
    end

    it "keeps revoked tokens younger than the refresh token lifetime" do
      revoked = issue_token(created_at: 2.days.ago, revoked_at: 2.days.ago)

      perform_job

      expect(::OauthAccessToken.exists?(revoked.id)).to be(true)
    end

    it "deletes used and expired grants and keeps a fresh one" do
      used = issue_grant(created_at: 2.days.ago, revoked_at: 2.days.ago)
      expired = issue_grant(created_at: 2.days.ago)
      fresh = issue_grant(created_at: 1.minute.ago)

      perform_job

      expect(::Doorkeeper::AccessGrant.where(id: [used.id, expired.id])).to be_empty
      expect(::Doorkeeper::AccessGrant.exists?(fresh.id)).to be(true)
    end

    it "leaves Connected Apps as it was" do
      # A client refreshed daily for six weeks: each refresh revoked the token before it.
      tokens = 42.downto(0).map { |days| issue_token(created_at: days.days.ago) }
      tokens[0...-1].each_with_index { |token, i| token.update!(revoked_at: tokens[i + 1].created_at) }
      # A client the user disconnected yesterday.
      other = ::OauthApplication.create!(name: "Claude Code", uid: "https://claude.ai/oauth/claude-code-client-metadata",
                                         confidential: false, redirect_uri: "http://localhost/callback", scopes: "read",
                                         metadata_fetched_at: Time.current)
      ::OauthAccessToken.create!(application: other, resource_owner_id: user.id, scopes: "read",
                                 expires_in: 1.hour.to_i, created_at: 3.days.ago, revoked_at: 1.day.ago)

      before = [::OauthApplication.connected_for(user).to_a, claude.last_authorized_at(user)]
      perform_job

      expect([::OauthApplication.connected_for(user).to_a, claude.last_authorized_at(user)]).to eq(before)
      expect(before.first).to eq([claude])
      expect(::OauthAccessToken.where(application: claude).count).to be < tokens.size
    end
  end
end
