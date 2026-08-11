class ApplicationNotification < Noticed::Event
  def self.deliver_by_email(method:)
    deliver_by :email, mailer: "UserMailer", method: method,
                       if: -> { recipient.notification_preference_email? }
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
  end
end
