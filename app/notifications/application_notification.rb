class ApplicationNotification < Noticed::Event
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
