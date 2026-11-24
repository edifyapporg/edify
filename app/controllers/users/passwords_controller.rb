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
  end
end
