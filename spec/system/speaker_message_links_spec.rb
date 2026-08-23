require "rails_helper"

describe "Send a pre-set message to a speaker" do
  let(:bishopric_user) { users(:sunny_bishopric) }
  let(:music_user) { users(:sunny_music) }
  let(:member) { members(:hill_waylon) }
  let(:meeting) { meetings(:meeting_2) }
  let(:past_meeting) { meetings(:meeting_11) }
  let(:past_talk) { talks(:talk_8) }
  let(:talk) { talks(:talk_2) }

  before { travel_to("2022-04-05") }

  context "when the user is in a bishopric" do
    before { login_as bishopric_user, scope: :user }

    it "offers text and email links on an upcoming talk" do
      visit meetings_path
      talk_row = page.find("#meeting_#{meeting.id}_talk_#{talk.id}")

      expect(talk_row).to have_link("Text: Invitation", href: /\Asms:6019156744\?&body=Hi%20Waylon/)
      expect(talk_row).to have_link("Text: Preparation guidance")
      expect(talk_row).to have_link("Email: Reminder", href: /\Amailto:jorge\.yost@oreilly\.info\?subject=/)
    end

    it "does not offer messaging on a meeting that has already happened" do
      visit meetings_path
      talk_row = page.find("#meeting_#{past_meeting.id}_talk_#{past_talk.id}")

      expect(talk_row).not_to have_css(".dropdown-item")
    end

    it "offers a link on an upcoming talk in the talks index" do
      visit talks_path
      talk_card = page.find("#meeting_#{meeting.id}_talk_#{talk.id}")

      expect(talk_card).to have_link("Text: Invitation", href: /\Asms:6019156744/)
      expect(talk_card).to have_link("Email: Invitation", href: /\Amailto:jorge\.yost@oreilly\.info/)
    end

    it "offers a date-free invitation from the member page" do
      visit member_path(member)

      expect(page).to have_link("Text: Invitation", href: /\Asms:6019156744\?&body=Hi%20Waylon/)
      expect(page).to have_link("Email: Invitation", href: /\Amailto:jorge\.yost@oreilly\.info/)
      expect(page).to have_no_link("Text: Invitation", href: /The%20meeting%20is%20on/)
    end
  end

  context "when the user is a music person" do
    before { login_as music_user, scope: :user }

    it "does not expose speaker contact information" do
      visit meetings_path

      expect(page).to have_no_css("a[href^='sms:']")
      expect(page).to have_no_css("a[href^='mailto:']")
    end
  end
end
