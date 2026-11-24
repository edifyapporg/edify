require "rails_helper"

describe "User signs in" do
  scenario "with correct credentials" do
    navigate_to_sign_in_page

    within("form") do
      fill_in "Email address", with: "bishopric@example.com"
      fill_in "Password", with: "password"
      click_button "Log in"
    end

    expect(page).to have_current_path(root_path)
    expect(page).to have_text("Signed in successfully.")
    expect(page).to have_text("Sunny Hills 3rd Ward")
  end

  scenario "with no credentials" do
    navigate_to_sign_in_page

    within("form") { click_button "Log in" }
    expect(page).to have_current_path(new_user_session_path)
    expect(page).to have_text("Invalid email or password.")
  end

  scenario "with no password" do
    navigate_to_sign_in_page

    within("form") do
      fill_in "Email address", with: "bishopric@example.com"
      click_button "Log in"
    end

    expect(page).to have_current_path(new_user_session_path)
    expect(page).to have_text("Invalid email or password.")
  end

  scenario "with wrong password" do
    navigate_to_sign_in_page

    within("form") do
      fill_in "Email address", with: "bishopric@example.com"
      fill_in "Password", with: "wrongpassword"
      click_button "Log in"
    end

    expect(page).to have_current_path(new_user_session_path)
    expect(page).to have_text("Invalid email or password.")
  end

  scenario "with nonexistent email" do
    navigate_to_sign_in_page

    within("form") do
      fill_in "Email address", with: "nonexistent@example.com"
      fill_in "Password", with: "password"
      click_button "Log in"
    end

    expect(page).to have_current_path(new_user_session_path)
    expect(page).to have_text("Invalid email or password.")
  end

  scenario "with an authenticator app" do
    user = users(:sunny_bishopric)
    user.update!(two_factor_method: :authenticator, otp_secret: User.generate_otp_secret)
    navigate_to_sign_in_page

    within("form") do
      fill_in "Email address", with: "bishopric@example.com"
      fill_in "Password", with: "password"
      click_button "Log in"
    end

    expect(page).to have_current_path(new_user_sign_in_code_path)
    expect(page).to have_text("Enter your code")

    fill_in "Code", with: user.current_otp
    click_button "Verify"

    expect(page).to have_current_path(root_path)
    expect(page).to have_text("Signed in successfully.")
  end

  def navigate_to_sign_in_page
    visit root_path
    click_link "Login"
    expect(page).to have_current_path(new_user_session_path)
  end
end
