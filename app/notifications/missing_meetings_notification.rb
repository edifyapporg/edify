class MissingMeetingsNotification < ApplicationNotification
  deliver_by :email, mailer: "UserMailer", method: :missing_meetings_notification,
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

  required_param :dates

  notification_methods do
    def message
      t(".message", date_string: date_string, count: params[:dates].size)
    end

    def subject
      t(".subject")
    end

    def url
      meetings_url
    end

    def date_string
      params[:dates].map { |date| ::I18n.l(date, format: :month_and_day) }.to_sentence
    end
  end
end
