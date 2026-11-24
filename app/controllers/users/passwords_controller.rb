module Users
  # Devise's password reset, telling the user what the new password did to their connected apps and API tokens (#390).
  class PasswordsController < Devise::PasswordsController
    include PasswordChangeNotice

    def update
      super
      append_password_change_notice(resource) if resource.errors.empty? && resource.saved_change_to_encrypted_password?
    end
  end
end
