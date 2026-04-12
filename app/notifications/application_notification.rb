class ApplicationNotification < Noticed::Event
  def self.deliver_by_email(method:)
    deliver_by :email, mailer: "UserMailer", method: method, if: -> { notify_by_email? }
  end

  def self.deliver_by_sms
    deliver_by :twilio_messaging,
               json: lambda {
                 {
                   Body: "#{message} #{url}",
                   From: Rails.application.credentials.twilio[:phone_number],
                   To: recipient.phone_number,
                 }
               },
               if: -> { notify_by_sms? }
  end

  notification_methods do
    def message
      raise NotImplementedError, "Notification must implement #message"
    end

    def subject
      raise NotImplementedError, "Notification must implement #subject"
    end

    def url
      raise NotImplementedError, "Notification must implement #url"
    end

    def notify_by_email?
      recipient.notification_preference_email?
    end

    def notify_by_sms?
      recipient.notification_preference_sms?
    end
  end
end
