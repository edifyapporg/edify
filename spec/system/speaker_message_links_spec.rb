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

    it "emails a reminder from an upcoming talk on the meetings page" do
      visit meetings_path
      talk_row = page.find("#meeting_#{meeting.id}_talk_#{talk.id}")

      expect(talk_row).to have_link(href: /\Amailto:jorge\.yost@oreilly\.info\?subject=Reminder/)
      expect(talk_row).to have_no_css("a[href^='sms:']")
    end

    it "does not offer messaging on a meeting that has already happened" do
      visit meetings_path
      talk_row = page.find("#meeting_#{past_meeting.id}_talk_#{past_talk.id}")

      expect(talk_row).to have_no_css("a[href^='mailto:']")
    end

    it "offers both a text and an email on an upcoming talk in the talks index" do
      visit talks_path
      talk_card = page.find("#meeting_#{meeting.id}_talk_#{talk.id}")

      expect(talk_card).to have_link("Text: Invitation", href: /\Asms:6019156744/)
      expect(talk_card).to have_link("Email: Invitation", href: /\Amailto:jorge\.yost@oreilly\.info/)
    end

    it "picks a Sunday to invite a member for from the member page" do
      visit member_path(member)

      expect(page).to have_select(options: ["April 10", "April 17", "April 24", "May 1", "May 8", "May 15"])
      expect(page).to have_link("Text invitation", href: /\Asms:6019156744\?&body=Hi%20Brother%20Hill/)
    end

    it "rewrites the invitation for whichever Sunday is picked", :js do
      visit member_path(member)

      expect(page.find_link("Text invitation")[:href])
        .to include(ERB::Util.url_encode("Sacrament Meeting on Sunday, April 10."))

      page.find("select").select("May 8")

      expect(page.find_link("Text invitation")[:href])
        .to include(ERB::Util.url_encode("Sacrament Meeting on Sunday, May 8."))
    end

    it "does not offer to email from the member page" do
      visit member_path(member)

      expect(page).to have_no_css("a[href^='mailto:']")
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
