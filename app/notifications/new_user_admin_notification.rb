class NewUserAdminNotification < ApplicationNotification
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
