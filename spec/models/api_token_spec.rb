require "rails_helper"

describe ::ApiToken do
  let(:user) { users(:sunny_bishopric) }

  def create_token(**attributes)
    described_class.create!(user: user, name: "Laptop CLI", **attributes)
  end

  describe "token generation" do
    subject { create_token }

    it "gives the creating instance a prefixed plaintext token" do
      expect(subject.plaintext_token).to match(/\Aedify_[1-9A-HJ-NP-Za-km-z]{32}\z/)
    end

    it "stores only the SHA-256 digest of the token" do
      expect(subject.token_digest).to eq(::OpenSSL::Digest::SHA256.hexdigest(subject.plaintext_token))
      expect(subject.attributes.values).not_to include(subject.plaintext_token)
    end

    it "cannot recover the plaintext token once reloaded" do
      expect(described_class.find(subject.id).plaintext_token).to be_nil
    end

    it "generates a different token each time" do
      expect(create_token.plaintext_token).not_to eq(create_token.plaintext_token)
    end

    it "keeps the digest when the token is updated" do
      digest = subject.token_digest
      subject.update!(name: "Renamed")
      expect(subject.reload.token_digest).to eq(digest)
    end

    it "defaults to read-only" do
      expect(subject.scopes).to eq(["read"])
    end
  end

  describe "validations" do
    it "requires a name" do
      token = described_class.new(user: user, name: " ")
      expect(token).not_to be_valid
      expect(token.errors.full_messages).to include("Name can't be blank")
    end

    it "limits the name to 100 characters" do
      expect(described_class.new(user: user, name: "x" * 101)).not_to be_valid
    end

    it "accepts the read and write scopes" do
      expect(described_class.new(user: user, name: "CLI", scopes: %w[read write])).to be_valid
    end

    it "rejects an unknown scope" do
      token = described_class.new(user: user, name: "CLI", scopes: %w[read admin])
      expect(token).not_to be_valid
      expect(token.errors.full_messages).to include("Scopes include unknown scopes: admin")
    end

    it "requires at least one scope" do
      token = described_class.new(user: user, name: "CLI", scopes: [])
      expect(token).not_to be_valid
      expect(token.errors.full_messages).to include("Scopes must include at least one scope")
    end

    it "refuses to create a token when the guidance was explicitly not acknowledged" do
      token = described_class.new(user: user, name: "CLI", guidance_acknowledged: false)
      expect(token).not_to be_valid
      expect(token.errors.full_messages).to include(I18n.t("models.api_token.guidance_not_acknowledged"))
    end

    it "creates a token when the guidance was acknowledged or not asked about" do
      expect(described_class.new(user: user, name: "CLI", guidance_acknowledged: true)).to be_valid
      expect(described_class.new(user: user, name: "CLI")).to be_valid
    end

    it "checks the acknowledgment only on create" do
      token = described_class.create!(user: user, name: "CLI")
      token.guidance_acknowledged = false
      expect(token).to be_valid
    end

    it "rejects an expiry in the past on create" do
      token = described_class.new(user: user, name: "CLI", expires_at: 1.minute.ago)
      expect(token).not_to be_valid
      expect(token.errors.full_messages).to include("Expires at must be in the future")
    end

    context "when the user is not assigned to a unit" do
      let(:user) { users(:unassigned) }

      it "cannot create a token" do
        token = described_class.new(user: user, name: "CLI")
        expect(token).not_to be_valid
        expect(token.errors.full_messages).to include("User must be assigned to a unit to create an API token")
      end
    end
  end

  describe ".authenticate" do
    let!(:token) { create_token }
    let(:result) { described_class.authenticate(plaintext) }
    let(:plaintext) { token.plaintext_token }

    it "finds an active token by its plaintext" do
      expect(result).to eq(token)
    end

    context "when the token is unknown" do
      let(:plaintext) { "edify_not-a-real-token" }
      it { expect(result).to be_nil }
    end

    context "when the token is blank" do
      let(:plaintext) { "" }
      it { expect(result).to be_nil }
    end

    context "when the token is nil" do
      let(:plaintext) { nil }
      it { expect(result).to be_nil }
    end

    context "when the token has been revoked" do
      before { token.revoke! }

      it { expect(result).to be_nil }
    end

    context "when the token has expired" do
      let!(:token) { create_token(expires_at: 1.day.from_now) }

      it "finds it before expiry and not after" do
        expect(result).to eq(token)
        travel_to(2.days.from_now) { expect(described_class.authenticate(plaintext)).to be_nil }
      end
    end
  end

  describe "#expires_in=" do
    it "sets the expiry from now for each choice" do
      freeze_time do
        expect(described_class.new(expires_in: "30d").expires_at).to eq(30.days.from_now)
        expect(described_class.new(expires_in: "90d").expires_at).to eq(90.days.from_now)
        expect(described_class.new(expires_in: "1y").expires_at).to eq(1.year.from_now)
      end
    end

    it "clears the expiry for never" do
      expect(described_class.new(expires_at: 1.day.from_now, expires_in: "never").expires_at).to be_nil
    end

    it "rejects an unknown choice without setting an expiry" do
      token = described_class.new(user: user, name: "CLI", expires_in: "forever")
      expect(token.expires_at).to be_nil
      expect(token).not_to be_valid
      expect(token.errors.full_messages).to include("Expires in is not a valid choice")
    end

    it "is optional for code that sets expires_at directly" do
      expect(described_class.new(user: user, name: "CLI", expires_at: 1.day.from_now)).to be_valid
    end

    it "has a label for every choice" do
      described_class::EXPIRY_CHOICES.each_key do |code|
        expect(I18n.t("models.api_token.expiry_choices.#{code}", raise: true)).to be_present
      end
    end
  end

  describe "status" do
    subject! { create_token(expires_at: 1.day.from_now) }

    it "is active when neither revoked nor expired" do
      expect(subject).to be_active
      expect(subject).not_to be_revoked
      expect(subject).not_to be_expired
    end

    it "is expired and inactive after its expiry" do
      travel_to(2.days.from_now) do
        expect(subject).to be_expired
        expect(subject).not_to be_active
      end
    end

    it "never expires without an expiry" do
      expect(create_token).not_to be_expired
    end
  end

  describe "#revoke!" do
    subject { create_token }

    it "revokes the token" do
      freeze_time do
        subject.revoke!
        expect(subject.reload.revoked_at).to eq(Time.current)
        expect(subject).to be_revoked
        expect(subject).not_to be_active
      end
    end

    it "keeps the original revocation time when called again" do
      subject.revoke!
      first_revoked_at = subject.reload.revoked_at
      travel_to(1.hour.from_now) { subject.revoke! }
      expect(subject.reload.revoked_at).to eq(first_revoked_at)
    end
  end

  describe "#scope?" do
    subject { create_token(scopes: %w[read]) }

    it "accepts a string or a symbol" do
      expect(subject.scope?(:read)).to eq(true)
      expect(subject.scope?("read")).to eq(true)
      expect(subject.scope?(:write)).to eq(false)
    end
  end

  describe "#touch_last_used!" do
    subject { create_token }

    it "records the first use" do
      freeze_time do
        subject.touch_last_used!
        expect(subject.reload.last_used_at).to eq(Time.current)
      end
    end

    it "does not write again within the throttle window" do
      subject.touch_last_used!
      first_use = subject.reload.last_used_at
      travel_to(described_class::LAST_USED_THROTTLE.from_now - 1.second) { subject.touch_last_used! }
      expect(subject.reload.last_used_at).to eq(first_use)
    end

    it "writes again once the throttle window has passed" do
      subject.touch_last_used!
      later = described_class::LAST_USED_THROTTLE.from_now + 1.second
      travel_to(later) do
        subject.touch_last_used!
        expect(subject.reload.last_used_at).to be_within(1.second).of(later)
      end
    end

    it "does not change updated_at" do
      updated_at = subject.updated_at
      travel_to(1.hour.from_now) { subject.touch_last_used! }
      expect(subject.reload.updated_at).to eq(updated_at)
    end
  end

  describe "when the user is destroyed" do
    it "destroys the user's tokens" do
      token = create_token
      user.destroy!
      expect(described_class.exists?(token.id)).to eq(false)
    end
  end
end
