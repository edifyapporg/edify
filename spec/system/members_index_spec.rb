require "rails_helper"

describe "Visit the members index" do
  let(:unit) { units(:sunny_hills) }
  let(:bishopric_user) { users(:sunny_bishopric) }
  let(:clerk_user) { users(:sunny_clerk) }
  let(:music_user) { users(:sunny_music) }
  let(:program_user) { users(:sunny_program) }
  let(:unassigned_user) { users(:unassigned) }
  let(:new_unit_user) { users(:new_unit) }

  context "when the user is a visitor" do
    it "does not permit access" do
      visit members_path
      expect(page).to have_current_path(new_user_session_path)
      expect(page).to have_content("You need to sign in or sign up before continuing")
    end
  end

  context "when the user is in a bishopric" do
    before { login_as bishopric_user, scope: :user }

    it "lists all members with edit tools" do
      visit members_path
      verify_members_present
      verify_editing_tools_present
    end
  end

  context "when the user is a clerk" do
    before { login_as clerk_user, scope: :user }

    it "lists all members with edit tools" do
      visit members_path
      verify_members_present
      verify_editing_tools_present
    end
  end

  context "when the user is a music person" do
    before { login_as music_user, scope: :user }

    it "does not permit access" do
      visit members_path
      expect(page).to have_current_path(root_path)
      expect(page).to have_content("Not authorized")
    end
  end

  context "when the user is a program person" do
    before { login_as program_user, scope: :user }

    it "does not permit access" do
      visit members_path
      expect(page).to have_current_path(root_path)
      expect(page).to have_content("Not authorized")
    end
  end

  context "when the user is not assigned to a ward" do
    before { login_as unassigned_user, scope: :user }

    it "does not permit access" do
      visit members_path
      expect(page).to have_current_path(root_path)
      expect(page).to have_content("Not authorized")
    end
  end

  context "when hiding moved members", :js do
    before { login_as bishopric_user, scope: :user }

    let(:current_member) { members(:bartell_randal) } # synced in the most recent import
    let(:moved_member) { members(:hill_waylon) } # synced before the most recent import
    let(:youth_member) do
      unit.members.create!(name: "Young, Teen", gender: :male,
                           birthdate: 15.years.ago.to_date, synced_on: unit.last_synced_on)
    end

    it "starts checked and hides members not in the most recent import" do
      visit members_path

      expect(page).to have_checked_field("Hide moved members")
      expect(page).to have_selector("#member_#{current_member.id}")
      expect(page).to have_no_selector("#member_#{moved_member.id}")
    end

    it "restores moved members when the checkbox is unchecked" do
      visit members_path
      expect(page).to have_no_selector("#member_#{moved_member.id}")

      uncheck "Hide moved members"

      expect(page).to have_selector("#member_#{current_member.id}")
      expect(page).to have_selector("#member_#{moved_member.id}")
      expect(page).to have_unchecked_field("Hide moved members")
    end

    it "remembers the choice on the user record across visits" do
      visit members_path
      uncheck "Hide moved members"
      expect(page).to have_selector("#member_#{moved_member.id}")
      expect(bishopric_user.reload.hide_moved_members).to be(false)

      visit members_path

      expect(page).to have_unchecked_field("Hide moved members")
      expect(page).to have_selector("#member_#{moved_member.id}")
    end

    it "hides them again when the checkbox is re-checked" do
      bishopric_user.update!(hide_moved_members: false)

      visit members_path
      expect(page).to have_selector("#member_#{moved_member.id}")

      check "Hide moved members"

      expect(page).to have_selector("#member_#{current_member.id}")
      expect(page).to have_no_selector("#member_#{moved_member.id}")
      expect(bishopric_user.reload.hide_moved_members).to be(true)
    end

    it "keeps the choice while sorting and filtering" do
      visit members_path

      within("#sort_and_filter_dropdowns") do
        click_on "All ages"
        click_on "Adults"
      end

      expect(page).to have_checked_field("Hide moved members")
      expect(page).to have_no_selector("#member_#{moved_member.id}")
    end

    it "keeps the active filter when the checkbox is toggled" do
      youth_member

      visit members_path
      within("#sort_and_filter_dropdowns") do
        click_on "All ages"
        click_on "Adults"
      end
      expect(page).to have_no_selector("#member_#{youth_member.id}") # the filter has landed

      uncheck "Hide moved members"

      expect(page).to have_selector("#member_#{moved_member.id}") # an adult, synced before the last import
      expect(page).to have_no_selector("#member_#{youth_member.id}")
      within("#sort_and_filter_dropdowns") { expect(page).to have_button("Adults") }
    end

    it "leaves every member visible when the unit has never been imported" do
      unit.update!(last_synced_on: nil)

      visit members_path

      expect(page).to have_selector("#member_#{current_member.id}")
      expect(page).to have_selector("#member_#{moved_member.id}")
      expect(page).to have_no_field("Hide moved members")
    end
  end

  context "with a possible-duplicates summary", :js do
    before do
      unit.update!(last_synced_on: Date.current)
      login_as bishopric_user, scope: :user
    end

    it "lazily shows a banner linking to the review page when duplicates exist" do
      unit.members.create!(name: "Twinny, Sam", gender: :male, birthdate: "1980-06-06", synced_on: Date.current)
      unit.members.create!(name: "Twinny, Sam Robert", gender: :male, birthdate: "1980-06-06", synced_on: Date.current)

      visit members_path

      expect(page).to have_content("possible duplicate")
      expect(page).to have_link("Review", href: members_possible_duplicates_path)
    end
  end

  # users.hide_moved_members defaults to true, so a bare visit lists the members
  # who were in the unit's most recent import.
  def current_members
    unit.members.reject(&:not_in_most_recent_sync?)
  end

  def verify_members_present
    expect(page).to have_text "Members"

    current_members.each do |member|
      member_card = page.find("#member_#{member.id}")
      expect(member_card).to have_text(member.name)
    end
  end

  def verify_editing_tools_present
    expect(page).to have_link(href: new_member_path)

    current_members.each do |member|
      member_card = page.find("#member_#{member.id}")
      expect(member_card).to have_link(href: edit_member_path(member))
      expect(member_card).to have_link(href: member_path(member))
    end
  end
end
