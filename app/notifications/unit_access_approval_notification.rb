class UnitAccessApprovalNotification < ApplicationNotification
  deliver_by_email method: :unit_access_approval_notification

  required_param :user

  notification_methods do
    def message
      t(".message", user_name: params[:user].name)
    end

    def subject
      t(".subject")
    end

    def url
      users_url
    end
  end
end
