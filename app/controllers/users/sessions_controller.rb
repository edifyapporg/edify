module Users
  # Devise's sign-in, rate-limited. When the password is right and the user has an authenticator app turned on,
  # the user isn't signed in yet: Edify asks for a code on a second page, handled by SignInCodesController.
  class SessionsController < Devise::SessionsController
    include AuthRateLimiting
    include PendingTwoFactorSignIn

    limit_auth_attempts :create, per_ip: 20, per_email: 10, within: 10.minutes
    before_action :ask_for_code, only: :create

    private

    def ask_for_code
      user = resource_class.find_for_database_authentication(email: params.dig(:user, :email).to_s)
      return unless user&.otp_required_for_login && user.valid_password?(params.dig(:user, :password).to_s)

      remember_me = ::ActiveModel::Type::Boolean.new.cast(params.dig(:user, :remember_me)) == true
      start_two_factor_sign_in(user, remember_me: remember_me)
      redirect_to new_user_sign_in_code_path, status: :see_other
    end
  end
end
