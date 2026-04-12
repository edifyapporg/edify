class MissingMeetingsNotification < ApplicationNotification
  deliver_by_email method: :missing_meetings_notification
  deliver_by_sms

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
