require "rails_helper"

RSpec.describe ::Oauth::ClientIdMetadataDocument do
  let(:client_id) { "https://claude.ai/oauth/mcp-client-metadata" }
  let(:document) do
    {
      client_id: client_id,
      client_name: "Claude",
      redirect_uris: ["https://claude.ai/api/mcp/auth_callback"],
      token_endpoint_auth_method: "none",
    }
  end

  before { allow(described_class::Fetcher).to receive(:call) { document.to_json } }

  describe ".client_id?" do
    it "accepts an https URL with a path on a trusted host" do
      expect(described_class.client_id?(client_id)).to be(true)
    end

    it "refuses other hosts, plain http, a bare host, a port, credentials and fragments" do
      ["https://evil.example/client.json", "http://claude.ai/client.json", "https://claude.ai/",
       "https://claude.ai:8443/client.json", "https://user@claude.ai/client.json",
       "https://claude.ai/client.json#frag", "not a url", "abc123"].each do |uid|
        expect(described_class.client_id?(uid)).to be(false), uid
      end
    end
  end

  describe "#application" do
    subject(:application) { described_class.new(client_id).application }

    it "creates a public client from the document" do
      expect(application).to be_persisted
      expect(application).to have_attributes(uid: client_id, name: "Claude", confidential: false, scopes: ["read"],
                                             redirect_uris: ["https://claude.ai/api/mcp/auth_callback"])
      expect(application.secret).to be_nil
    end

    it "reuses a fresh copy without fetching again" do
      described_class.new(client_id).application
      described_class.new(client_id).application

      expect(described_class::Fetcher).to have_received(:call).once
    end

    it "fetches again after a day and applies changes" do
      described_class.new(client_id).application
      document[:client_name] = "Claude (renamed)"

      travel(25.hours) { expect(application.name).to eq("Claude (renamed)") }
      expect(::OauthApplication.where(uid: client_id).count).to eq(1)
    end

    it "keeps using the last good copy when a refresh fails" do
      described_class.new(client_id).application
      allow(described_class::Fetcher).to receive(:call).and_raise(described_class::Fetcher::Error, "HTTP 503")

      travel(25.hours) { expect(application.name).to eq("Claude") }
    end

    it "keeps the last good values, not a rejected refresh's, when the new document is invalid" do
      described_class.new(client_id).application
      document[:client_name] = "Renamed"
      document[:redirect_uris] = ["http://claude.ai/callback"]

      refreshed = travel(25.hours) { application }

      expect(refreshed).to have_attributes(name: "Claude", redirect_uris: ["https://claude.ai/api/mcp/auth_callback"])
      expect(refreshed).not_to be_changed
    end

    it "returns nil when the document has never been fetched" do
      allow(described_class::Fetcher).to receive(:call).and_raise(described_class::Fetcher::Error, "timeout")
      expect(application).to be_nil
    end

    it "refuses a document whose client_id doesn't match its URL" do
      document[:client_id] = "https://claude.ai/someone-else"
      expect(application).to be_nil
    end

    it "refuses a document without a name or redirect URIs" do
      document.delete(:client_name)
      expect(application).to be_nil

      document[:client_name] = "Claude"
      document[:redirect_uris] = []
      expect(described_class.new(client_id).application).to be_nil
    end

    it "refuses a document that isn't JSON" do
      allow(described_class::Fetcher).to receive(:call).and_return("<html>")
      expect(application).to be_nil
    end

    it "refuses redirect URIs that are plain http away from this computer" do
      document[:redirect_uris] = ["http://claude.ai/callback"]
      expect(application).to be_nil
    end

    it "accepts loopback redirects, as Claude Code registers" do
      document[:redirect_uris] = ["http://localhost/callback", "http://127.0.0.1/callback"]
      expect(application.redirect_uris).to eq(["http://localhost/callback", "http://127.0.0.1/callback"])
    end
  end
end
