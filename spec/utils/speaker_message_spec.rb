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

    it "invites the speaker to the meeting on its date" do
      expect(message.email_body)
        .to include("The Bishopric would like to invite you to speak in sacrament meeting on Sunday, April 10.")
    end

    it "gives the length of the talk and the assigned topic" do
      expect(message.email_body)
        .to include("Your talk will be approximately 8-10 minutes in length, and your assigned topic is It Is Finished.")
    end

    it "tells the speaker what to focus on and what to avoid" do
      expect(message.email_body).to include("Please focus on:", "* Keeping your message centered on Jesus Christ.")
      expect(message.email_body).to include("Please also keep in mind:", "* Avoid political or divisive topics.")
    end

    it "names the time the meeting must conclude by" do
      expect(message.email_body).to include("so the meeting concludes by 9:55 am, or before")
    end

    it "signs the message from the bishopric" do
      expect(message.email_body).to end_with("Sincerely,\nThe Bishopric")
    end

    it "greets the speaker by surname in the text message and introduces the sender" do
      expect(message.sms_body).to start_with("Hi Brother Hill, this is Brother User from the bishopric.")
    end

    it "asks about the date and the length in the text message" do
      expect(message.sms_body)
        .to include("invite you to speak in Sacrament Meeting on Sunday, April 10. You would speak for 8-10 minutes.",
                    "Are you in town and available to speak that day?")
    end

    context "when the speaker is a youth" do
      let(:member) { Member.new(name: "Wilderman, Kati", gender: :female, birthdate: 15.years.ago.to_date) }
      let(:message) do
        described_class.new(template: :invitation, member: member, speaker_name: member.name, sender: sender,
                            meeting_date: talk.date, topic: talk.topic)
      end

      it "uses the shorter talk length and the matching honorific" do
        expect(message.sms_body).to start_with("Hi Sister Wilderman,")
        expect(message.sms_body).to include("You would speak for 3-5 minutes.")
        expect(message.email_body).to include("approximately 3-5 minutes in length")
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

      it "falls back to introducing an unnamed member of the bishopric" do
        expect(message.sms_body).to start_with("Hi Brother Hill, this is a member of the bishopric.")
      end
    end
  end

  describe ".for_member" do
    subject(:message) { described_class.for_member(member, template: :invitation, sender: sender) }

    it "falls back to an invitation that names no meeting date" do
      expect(message.email_body).to start_with("Dear Waylon,")
      expect(message.email_body)
        .to include("The Bishopric would like to invite you to speak in sacrament meeting. We look forward")
      expect(message.email_body).not_to include("sacrament meeting on")
    end

    it "falls back to giving the length without a topic" do
      expect(message.email_body).to include("Your talk will be approximately 8-10 minutes in length.")
      expect(message.email_body).not_to include("your assigned topic is")
    end

    it "falls back to a text message that asks about no particular day" do
      expect(message.sms_body).to include("Are you available to speak?")
      expect(message.sms_body).not_to include("Sacrament Meeting on")
    end

    context "when a meeting date is given" do
      subject(:message) do
        described_class.for_member(member, template: :invitation, meeting_date: Date.new(2022, 5, 15), sender: sender)
      end

      it "uses the dated invitation instead of the fallback" do
        expect(message.email_body).to include("speak in sacrament meeting on Sunday, May 15.")
        expect(message.email_body.scan("would like to invite you to speak").length).to eq(1)
      end

      it "uses the dated text message instead of the fallback" do
        expect(message.sms_body).to include("Sacrament Meeting on Sunday, May 15.")
        expect(message.sms_body).not_to include("Are you available to speak?")
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
