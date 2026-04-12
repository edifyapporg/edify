class NewUserNotification < ApplicationNotification
  # Sent on account confirmation, before the user has a chance to set notification
  # preferences, so it bypasses the usual recipient-preference guard.
  deliver_by :email, mailer: "UserMailer", method: :new_user_notification

  required_param :user

  notification_methods do
    def message
      t(".message")
    end

    def subject
      t(".subject")
    end

    def url
      root_url
    end

    def user
      params[:user]
    end
  end
end
