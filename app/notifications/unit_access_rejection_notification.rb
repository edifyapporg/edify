class UnitAccessRejectionNotification < ApplicationNotification
  deliver_by :email, mailer: "UserMailer", method: :unit_access_rejection_notification,
                     if: -> { recipient.notification_preference_email? }
  deliver_by :twilio_messaging,
             json: lambda {
               {
                 Body: "#{message} #{url}",
                 From: Rails.application.credentials.twilio[:phone_number],
                 To: recipient.phone_number,
               }
             },
             if: -> { recipient.notification_preference_sms? }

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
