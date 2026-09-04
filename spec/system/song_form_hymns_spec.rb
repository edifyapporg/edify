require "rails_helper"

describe "Hymn autocomplete on the song form" do
  let(:meeting) { meetings(:meeting_1) }
  let(:music_user) { users(:sunny_music) }
  let(:program_user) { users(:sunny_program) }

  context "when the user can edit music" do
    before { login_as music_user, scope: :user }

    it "renders every hymn as a datalist option attached to the title field" do
      visit new_meeting_song_path(meeting)

      title_field = page.find_field("Title")
      expect(title_field["list"]).to eq("hymns_autocomplete")

      datalist = page.find("datalist#hymns_autocomplete", visible: :all)
      options = datalist.all("option", visible: :all)
      expect(options.size).to eq(::Edify::Hymns.database.size)

      expect(datalist).to have_css('option[value="The Morning Breaks #1"]', visible: :all)
      expect(datalist).to have_css('option[value="Peace, Peace, Be Still #1063"]', visible: :all)
      expect(datalist).to have_css('option[value="When I Survey the Wondrous Cross #1072"]', visible: :all)
    end

    it "lists hymns in numeric order" do
      visit new_meeting_song_path(meeting)

      values = page.all("datalist#hymns_autocomplete option", visible: :all).map { |option| option[:value] }
      numbers = values.map { |value| value[/#(\d+)\z/, 1].to_i }
      expect(numbers).to eq(numbers.sort)
    end
  end

  context "when the user cannot edit music" do
    before { login_as program_user, scope: :user }

    it "does not render the song form" do
      visit new_meeting_song_path(meeting)
      expect(page).to have_content("Not authorized")
      expect(page).to have_no_css("datalist#hymns_autocomplete", visible: :all)
    end
  end
end
