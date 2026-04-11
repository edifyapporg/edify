class IncompleteMeetingNotification < ApplicationNotification
  deliver_by :email, mailer: "UserMailer", method: :incomplete_meeting_notification,
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

  required_param :meeting

  notification_methods do
    def message
      t(".message", meeting_type: meeting.meeting_type.titleize, date: date, count: meeting.talks.size)
    end

    def subject
      t(".subject", date: date)
    end

    def url
      meeting_url(meeting)
    end

    private

    def meeting
      params[:meeting]
    end

    def date
      ::I18n.l(meeting.date, format: :month_and_day)
    end
  end
end
