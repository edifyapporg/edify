require "rails_helper"

RSpec.describe "Signing in with an authenticator app" do
  let(:user) { users(:sunny_bishopric) }
  let!(:recovery_codes) do
    user.update!(two_factor_method: :authenticator, otp_secret: User.generate_otp_secret)
    codes = user.generate_otp_backup_codes!
    user.save!
    codes
  end

  def enter_password(password: "password", remember_me: "0")
    post user_session_path, params: { user: { email: user.email, password: password, remember_me: remember_me } }
  end

  def enter_code(code, ip: "203.0.113.1")
    post user_sign_in_code_path, params: { code: code }, env: { "REMOTE_ADDR" => ip }
  end

  def signed_in?
    get settings_preferences_path
    response.successful?
  end

  describe "the password step" do
    it "asks for a code instead of signing in" do
      enter_password

      expect(response).to redirect_to(new_user_sign_in_code_path)
      expect(controller.current_user).to be_nil
      follow_redirect!
      expect(response.body).to include("Enter your code")
    end

    it "rejects a wrong password as usual, without asking for a code" do
      enter_password(password: "wrong")

      expect(response).not_to redirect_to(new_user_sign_in_code_path)
      expect(flash[:alert]).to eq("Invalid email or password.")
    end

    it "doesn't ask a user without an authenticator app for a code" do
      user.update!(two_factor_method: :none)
      enter_password

      expect(response).to redirect_to(root_path)
      expect(controller.current_user).to eq(user)
    end
  end

  describe "the code step" do
    before { enter_password }

    it "signs in with the app's current code" do
      enter_code(user.current_otp)

      expect(response).to redirect_to(root_path)
      expect(flash[:notice]).to eq("Signed in successfully.")
      expect(signed_in?).to be(true)
    end

    it "accepts the code with a space in the middle" do
      enter_code(user.current_otp.insert(3, " "))

      expect(signed_in?).to be(true)
    end

    it "refuses a wrong code" do
      enter_code("000000")

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("That code didn&#39;t work.")
      expect(signed_in?).to be(false)
    end

    it "refuses a code that was already used" do
      code = user.current_otp
      enter_code(code)
      delete destroy_user_session_path
      enter_password
      enter_code(code)

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "signs in with a recovery code, once" do
      enter_code(recovery_codes.first.upcase)

      expect(flash[:notice]).to eq("Signed in with a recovery code. You have 9 recovery codes left.")
      expect(signed_in?).to be(true)

      delete destroy_user_session_path
      enter_password
      enter_code(recovery_codes.first)

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "returns to the page the user was going to" do
      delete destroy_user_session_path
      get settings_preferences_path
      enter_password
      enter_code(user.current_otp)

      expect(response).to redirect_to(settings_preferences_path)
    end
  end

  it "remembers the user when Remember me was checked" do
    enter_password(remember_me: "1")
    enter_code(user.current_otp)

    expect(cookies["remember_user_token"]).to be_present
  end

  it "doesn't remember the user otherwise" do
    enter_password
    enter_code(user.current_otp)

    expect(cookies["remember_user_token"]).to be_blank
  end

  it "sends the user back to the password step when no password was entered" do
    enter_code(user.current_otp)

    expect(response).to redirect_to(new_user_session_path)
    expect(signed_in?).to be(false)
  end

  it "sends the user back to the password step after 5 minutes" do
    enter_password
    travel 6.minutes
    enter_code(user.current_otp)

    expect(response).to redirect_to(new_user_session_path)
    expect(flash[:alert]).to eq("Your sign-in timed out. Enter your email address and password again.")
    expect(signed_in?).to be(false)
  end

  it "sends the user back to the password step if the password changed in between" do
    enter_password
    user.update!(password: "a-new-password-123")
    enter_code(user.current_otp)

    expect(response).to redirect_to(new_user_session_path)
    expect(signed_in?).to be(false)
  end

  describe "rate limits" do
    let(:store) { ActiveSupport::Cache::MemoryStore.new }

    before do
      allow(Rails.cache).to receive(:increment) { |*args, **options| store.increment(*args, **options) }
      enter_password
    end

    it "refuses an account after 10 codes in 10 minutes, even a right one" do
      10.times { |i| enter_code("000000", ip: "203.0.113.#{i + 1}") }
      enter_code(user.current_otp, ip: "198.51.100.1")

      expect(response).to redirect_to(new_user_sign_in_code_path)
      expect(flash[:alert]).to eq("Too many attempts. Wait a few minutes and try again.")
      expect(signed_in?).to be(false)
    end
  end

  describe "resetting the password" do
    it "doesn't sign the user in afterward" do
      token = user.send_reset_password_instructions
      put user_password_path, params: { user: { reset_password_token: token, password: "a-new-password-123",
                                                password_confirmation: "a-new-password-123" } }

      expect(response).to redirect_to(new_user_session_path)
      expect(flash[:notice]).to eq("Your password has been changed successfully.")
      expect(signed_in?).to be(false)
    end
  end
end
