require "rails_helper"

describe "Update notification preferences", :js do
  let(:user) { users(:sunny_bishopric) }

  before { login_as user, scope: :user }

  # The switch has no submit button -- form-auto-submit saves it on change --
  # so this covers that shared Stimulus controller as well as the preference.
  it "saves the email notification switch as soon as it is toggled" do
    visit settings_preferences_path
    expect(page).to have_checked_field("email-switch-check-box")

    uncheck "email-switch-check-box"

    expect(page).to have_unchecked_field("email-switch-check-box")
    expect(page).to have_current_path(settings_preferences_path)
    expect(user.reload.notification_preference_email).to be(false)
  end
end
