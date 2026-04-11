class NewUserNotification < ApplicationNotification
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
