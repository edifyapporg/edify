require "rails_helper"

RSpec.describe SpeakerMessagesHelper, type: :helper do
  let(:member) { members(:hill_waylon) }
  let(:talk) { talks(:talk_2) }
  let(:unit) { units(:sunny_hills) }
  let(:user) { users(:sunny_bishopric) }

  before do
    without_partial_double_verification do
      allow(helper).to receive_messages(current_user: user, current_unit: unit)
    end
  end

  describe "#speaker_message_dropdown_for_member" do
    subject(:dropdown) { helper.speaker_message_dropdown_for_member(member) }

    it "offers a text and an email link for each template" do
      expect(dropdown).to include("Text: Invitation", "Text: Preparation guidance", "Text: Reminder")
      expect(dropdown).to include("Email: Invitation", "Email: Preparation guidance", "Email: Reminder")
    end

    it "links to the member's phone number and email" do
      expect(dropdown).to include("sms:6019156744?")
      expect(dropdown).to include("mailto:jorge.yost@oreilly.info?")
    end

    context "when the member has no phone number" do
      before { member.update_column(:phone_number, nil) }

      it "offers only email links" do
        expect(dropdown).to include("Email: Invitation")
        expect(dropdown).not_to include("Text: Invitation")
      end
    end

    context "when the member has no phone number or email" do
      before { member.update_columns(email: nil, phone_number: nil) }

      it { expect(dropdown).to be_nil }
    end

    context "when only one medium is asked for" do
      subject(:dropdown) { helper.speaker_message_dropdown_for_member(member, media: :sms) }

      it "offers a text link for each template and no email links" do
        expect(dropdown).to include("Text: Invitation", "Text: Preparation guidance", "Text: Reminder")
        expect(dropdown).not_to include("Email:", "mailto:")
      end

      context "when the member has no phone number" do
        before { member.update_column(:phone_number, nil) }

        it "falls away rather than offering the email links it was not asked for" do
          expect(dropdown).to be_nil
        end
      end
    end
  end

  describe "#speaker_message_dropdown_for_talk" do
    subject(:dropdown) { helper.speaker_message_dropdown_for_talk(talk) }

    it "links to the matched member" do
      expect(dropdown).to include("sms:6019156744?", "mailto:jorge.yost@oreilly.info?")
    end

    context "when the speaker is not matched to a member" do
      let(:talk) { talks(:talk_3) }

      it { expect(dropdown).to be_nil }
    end

    context "when only email is asked for" do
      subject(:dropdown) { helper.speaker_message_dropdown_for_talk(talk, media: :email) }

      it "offers an email link for each template and no text links" do
        expect(dropdown).to include("Email: Invitation", "Email: Preparation guidance", "Email: Reminder")
        expect(dropdown).not_to include("Text:", "sms:")
      end
    end
  end
end
