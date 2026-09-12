require "rails_helper"

RSpec.describe SpeakerMessagesHelper, type: :helper do
  let(:member) { members(:hill_waylon) }
  let(:talk) { talks(:talk_2) }
  let(:unit) { units(:sunny_hills) }
  let(:user) { users(:sunny_bishopric) }

  before do
    travel_to("2022-04-05") # a Tuesday, so the next Sunday is the 10th

    without_partial_double_verification do
      allow(helper).to receive_messages(current_user: user, current_unit: unit)
    end
  end

  describe "#invitation_sundays" do
    it "lists the next six Sundays" do
      expect(helper.invitation_sundays.map(&:to_s))
        .to eq(%w[2022-04-10 2022-04-17 2022-04-24 2022-05-01 2022-05-08 2022-05-15])
    end

    context "when today is a Sunday" do
      before { travel_to("2022-04-10") }

      it "starts with the Sunday after it, since today's meeting is too late to invite for" do
        expect(helper.invitation_sundays.first.to_s).to eq("2022-04-17")
      end
    end
  end

  describe "#speaker_invitation_box" do
    subject(:box) { helper.speaker_invitation_box(member) }

    it "offers each of the next six Sundays to pick from" do
      expect(box).to include("April 10", "April 17", "April 24", "May 1", "May 8", "May 15")
    end

    it "carries the message for every Sunday, not just the one showing" do
      expect(box).to include(ERB::Util.url_encode("Sacrament Meeting on Sunday, April 10."))
      expect(box).to include(ERB::Util.url_encode("Sacrament Meeting on Sunday, May 15."))
    end

    it "starts the link on the first Sunday" do
      expect(box).to include("href=\"sms:6019156744?&amp;body=#{ERB::Util.url_encode('Hi Brother Hill')}")
    end

    it "wires the picker to the link" do
      expect(box).to include("data-controller=\"speaker-invitation\"")
      expect(box).to include("data-action=\"change-&gt;speaker-invitation#pick\"")
    end

    context "when the member has no phone number" do
      before { member.update_column(:phone_number, nil) }

      it { expect(box).to be_nil }
    end
  end

  describe "#speaker_reminder_link" do
    subject(:link) { helper.speaker_reminder_link(talk) }

    it "emails the matched speaker a reminder" do
      expect(link).to include("mailto:jorge.yost@oreilly.info?subject=")
      expect(link).to include(ERB::Util.url_encode("Reminder: your talk in Sacrament Meeting"))
    end

    it "says who it reaches" do
      expect(link).to include('title="Email Waylon Hill a reminder"')
    end

    context "when the speaker is not matched to a member" do
      let(:talk) { talks(:talk_3) }

      it { expect(link).to be_nil }
    end

    context "when the member has no email" do
      before { member.update_column(:email, nil) }

      it { expect(link).to be_nil }
    end
  end

  describe "#speaker_message_dropdown_for_talk" do
    subject(:dropdown) { helper.speaker_message_dropdown_for_talk(talk) }

    it "offers a text and an email link for each template" do
      expect(dropdown).to include("Text: Invitation", "Text: Preparation guidance", "Text: Reminder")
      expect(dropdown).to include("Email: Invitation", "Email: Preparation guidance", "Email: Reminder")
    end

    it "links to the matched member" do
      expect(dropdown).to include("sms:6019156744?", "mailto:jorge.yost@oreilly.info?")
    end

    context "when the speaker is not matched to a member" do
      let(:talk) { talks(:talk_3) }

      it { expect(dropdown).to be_nil }
    end
  end

  describe "an unbaptized member of record" do
    before { member.update_column(:baptized, false) }

    it "is not offered an invitation" do
      expect(helper.speaker_invitation_box(member)).to be_nil
    end

    it "is not offered a reminder or a message from a talk" do
      expect(helper.speaker_reminder_link(talk)).to be_nil
      expect(helper.speaker_message_dropdown_for_talk(talk)).to be_nil
    end
  end

  describe "a member whose baptism status is unknown" do
    before { member.update_column(:baptized, nil) }

    it "is still offered an invitation" do
      expect(helper.speaker_invitation_box(member)).to be_present
    end
  end
end
