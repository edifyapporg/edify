class IncompleteMeetingNotification < ApplicationNotification
  deliver_by_email method: :incomplete_meeting_notification
  deliver_by_sms

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
