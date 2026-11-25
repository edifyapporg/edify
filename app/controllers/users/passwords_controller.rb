module Users
  # Devise's password reset, telling the user what the new password did to their connected apps and API tokens (#390).
  # Requests for a reset email are rate-limited (#391) so they can't be used to flood an inbox.
  class PasswordsController < Devise::PasswordsController
    include AuthRateLimiting
    include PasswordChangeNotice

    limit_auth_attempts :create, per_ip: 10, per_email: 3, within: 15.minutes

    def update
      super
      append_password_change_notice(resource) if resource.errors.empty? && resource.saved_change_to_encrypted_password?
    end

    protected

    # A reset link proves only access to the user's email, so a user with an authenticator app signs in afterward
    # with the new password and a code, instead of being signed in by the reset.
    def sign_in_after_reset_password?
      super && !resource.otp_required_for_login
    end
  end
end
