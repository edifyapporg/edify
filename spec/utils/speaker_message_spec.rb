require "rails_helper"

describe SpeakerMessage do
  let(:member) { members(:hill_waylon) }
  let(:sender) { users(:sunny_bishopric) }
  let(:talk) { talks(:talk_2) }
  let(:unit) { units(:sunny_hills) }

  describe ".for_talk" do
    subject(:message) { described_class.for_talk(talk, template: :invitation, sender: sender) }

    it "greets the speaker by first name" do
      expect(message.email_body).to start_with("Dear Waylon,")
    end

    it "names the unit that is inviting" do
      expect(message.email_body).to include("The bishopric of Sunny Hills 3rd Ward")
    end

    it "includes the date of the meeting" do
      expect(message.email_body).to include("The meeting is on Sunday, April 10.")
    end

    it "includes the topic of the talk" do
      expect(message.email_body).to include('We would like you to speak on the topic of "It Is Finished".')
    end

    it "signs the message with the sender's name" do
      expect(message.email_body).to end_with("Thank you,\nSunny Bishopric User")
    end

    it "omits segments for details the talk does not have" do
      expect(message.email_body).not_to include("Assignment:")
    end

    context "when the talk has a purpose" do
      let(:talk) { talks(:talk_1) }

      it "includes the purpose" do
        expect(message.email_body).to include("Assignment: Departing Missionary.")
      end
    end

    context "when the speaker is not matched to a member" do
      let(:talk) { talks(:talk_3) }

      it "has no way to reach the speaker" do
        expect(message).not_to be_available
        expect(message.sms_url).to be_nil
        expect(message.mailto_url).to be_nil
      end
    end

    context "when there is no sender" do
      subject(:message) { described_class.for_talk(talk, template: :invitation) }

      it "leaves off the signature" do
        expect(message.email_body).not_to include("Thank you,")
      end
    end
  end

  describe ".for_member" do
    subject(:message) { described_class.for_member(member, template: :invitation, sender: sender) }

    it "invites the member without naming a meeting date" do
      expect(message.email_body).to start_with("Dear Waylon,")
      expect(message.email_body).to include("would like to invite you to speak in Sacrament Meeting.")
      expect(message.email_body).not_to include("The meeting is on")
    end

    context "when a meeting date is given" do
      subject(:message) do
        described_class.for_member(member, template: :invitation, meeting_date: Date.new(2022, 5, 15), sender: sender)
      end

      it "includes the date" do
        expect(message.email_body).to include("The meeting is on Sunday, May 15.")
      end
    end
  end

  describe "#label" do
    it "returns the name of the template" do
      expect(described_class.for_member(member, template: :guidance).label).to eq("Preparation guidance")
      expect(described_class.label(:reminder)).to eq("Reminder")
    end
  end

  describe "#mailto_url" do
    subject(:url) { described_class.for_talk(talk, template: :reminder, sender: sender).mailto_url }

    it "addresses the member and pre-fills the subject and body" do
      expect(url).to start_with("mailto:jorge.yost@oreilly.info?subject=")
      expect(url).to include(ERB::Util.url_encode("Reminder: your talk in Sacrament Meeting"))
      expect(url).to include("&body=#{ERB::Util.url_encode('Dear Waylon,')}")
    end

    context "when the member has no email" do
      before { member.update_column(:email, nil) }

      it { expect(url).to be_nil }
    end
  end

  describe "#sms_url" do
    subject(:url) { described_class.for_talk(talk, template: :reminder, sender: sender).sms_url }

    it "strips the phone number to digits and pre-fills the body" do
      expect(url).to start_with("sms:6019156744?&body=")
      expect(url).to include(ERB::Util.url_encode("Hi Waylon,"))
    end

    it "keeps an international prefix" do
      member.update_column(:phone_number, "+1 (601) 915-6744")

      expect(url).to start_with("sms:+16019156744?&body=")
    end

    context "when the member has no phone number" do
      before { member.update_column(:phone_number, nil) }

      it { expect(url).to be_nil }
    end
  end

  describe "sms bodies" do
    subject(:message) { described_class.for_talk(talk, template: :guidance, sender: sender) }

    it "is shorter than the email body and uses single line breaks" do
      expect(message.sms_body.length).to be < message.email_body.length
      expect(message.sms_body).not_to include("\n\n")
    end
  end

  describe "templates" do
    it "builds a body for every template and medium" do
      described_class::TEMPLATES.each do |template|
        message = described_class.for_talk(talk, template: template, sender: sender)

        expect(message.subject).to be_present
        expect(message.email_body).to be_present
        expect(message.sms_body).to be_present
      end
    end

    it "rejects an unknown template" do
      expect { described_class.for_talk(talk, template: :thank_you) }
        .to raise_error(ArgumentError, "Unknown template: thank_you")
    end
  end

  describe "speaker names without a comma" do
    subject(:message) do
      described_class.new(template: :invitation, speaker_name: "Gordon Ghibli", unit: unit)
    end

    it "uses the first word as the first name" do
      expect(message.email_body).to start_with("Dear Gordon,")
    end
  end
end
