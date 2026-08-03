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
    before do
      unit.update!(last_synced_on: Date.new(2022, 4, 15))
      login_as bishopric_user, scope: :user
    end

    let!(:current_member) do
      unit.members.create!(name: "Current Person", gender: :male, birthdate: "1990-01-01", synced_on: Date.new(2022, 4, 15))
    end
    let!(:moved_member) do
      unit.members.create!(name: "Moved Person", gender: :male, birthdate: "1991-01-01", synced_on: Date.new(2022, 3, 1))
    end

    it "removes members not in the most recent import when the checkbox is checked" do
      visit members_path
      expect(page).to have_selector("#member_#{current_member.id}")
      expect(page).to have_selector("#member_#{moved_member.id}")

      check "Hide moved members"

      expect(page).to have_selector("#member_#{current_member.id}")
      expect(page).to have_no_selector("#member_#{moved_member.id}")
    end
  end

  def verify_members_present
    expect(page).to have_text "Members"

    unit.members.each do |member|
      member_card = page.find("#member_#{member.id}")
      expect(member_card).to have_text(member.name)
    end
  end

  def verify_editing_tools_present
    expect(page).to have_link(href: new_member_path)

    unit.members.each do |member|
      member_card = page.find("#member_#{member.id}")
      expect(member_card).to have_link(href: edit_member_path(member))
      expect(member_card).to have_link(href: member_path(member))
    end
  end
end
