class NewUserAdminNotification < ApplicationNotification
  # Admins should always be informed of new signups, regardless of their personal
  # notification preferences, so this bypasses the usual `notify_by_email?` guard.
  deliver_by :email, mailer: "UserMailer", method: :new_user_admin_notification

  required_param :user

  notification_methods do
    def message
      t(".message")
    end

    def subject
      t(".subject")
    end

    def url
      root_path
    end

    def user
      params[:user]
    end
  end
end
