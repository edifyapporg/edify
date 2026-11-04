require "rails_helper"

# The talk and song forms ask the server, through Stimulus, when the speaker last
# spoke or the hymn was last sung. These specs cover the round trip in a browser.
# The form shows these labels in uppercase, so the text matches ignore case.
describe "Last spoke and last sung messages", :js do
  # meeting_6 is in Sunny Hills on 2022-05-15. Barrows, Kenneth spoke and
  # "The Morning Breaks #1" was sung there on 2022-04-10.
  let(:meeting) { meetings(:meeting_6) }

  scenario "a bishopric member sees when the speaker last spoke" do
    login_as users(:sunny_bishopric), scope: :user
    visit new_meeting_talk_path(meeting)

    fill_in "Speaker name", with: "Barrows, Kenneth"
    find_field("Speaker name").send_keys(:tab)

    expect(page).to have_text(/previously spoke about 1 month before this meeting/i)
  end

  scenario "a music editor sees when the hymn was last sung" do
    login_as users(:sunny_music), scope: :user
    visit new_meeting_song_path(meeting)

    fill_in "Title", with: "The Morning Breaks #1"
    find_field("Title").send_keys(:tab)

    expect(page).to have_text(/previously sung about 1 month before this meeting/i)
  end
end
