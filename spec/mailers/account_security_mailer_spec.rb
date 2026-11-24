require "rails_helper"

RSpec.describe AccountSecurityMailer do
  let(:user) { users(:sunny_bishopric) }

  def bodies(mail)
    [mail.html_part.body.decoded, mail.text_part.body.decoded]
  end

  describe "#api_token_created" do
    let(:api_token) { user.api_tokens.create!(name: "Laptop CLI", expires_at: Time.zone.local(2027, 2, 21, 12)) }
    let(:mail) { described_class.api_token_created(api_token) }

    it "tells the user what was created and what to do if it wasn't them" do
      expect(mail.to).to eq([user.email])
      expect(mail.subject).to eq("New API token on your Edify account")
      expect(bodies(mail)).to all(include("Laptop CLI", "read", "21 Feb 2027", "/settings/api_tokens", "/users/password/new"))
    end

    it "never includes the token or its digest" do
      bodies(mail).each do |body|
        expect(body).not_to include(api_token.plaintext_token, api_token.token_digest)
      end
    end

    it "says a token without an expiry never expires" do
      api_token.update!(expires_at: nil)

      expect(bodies(mail)).to all(include("Expires: never"))
    end
  end

  describe "#app_connected" do
    let(:claude) do
      ::OauthApplication.create!(name: "Claude", uid: "https://claude.ai/oauth/mcp-client-metadata",
                                 confidential: false, redirect_uri: "https://claude.ai/api/mcp/auth_callback",
                                 scopes: "read", metadata_fetched_at: Time.current)
    end

    it "names the app and where to disconnect it" do
      mail = described_class.app_connected(user, claude, loopback: false)

      expect(mail.to).to eq([user.email])
      expect(mail.subject).to eq("New app connected to your Edify account")
      bodies(mail).each do |body|
        expect(body).to include("Claude", "claude.ai", "/settings/connected_apps", "/users/password/new")
        expect(body).not_to include("Claude Code")
      end
    end

    it "says when the app connected through a program on someone's computer" do
      mail = described_class.app_connected(user, claude, loopback: true)

      expect(bodies(mail)).to all(include("such as Claude Code"))
    end
  end
end
