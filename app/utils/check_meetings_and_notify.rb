class CheckMeetingsAndNotify
  def self.perform!(unit)
    new(unit).perform!
  end

  def initialize(unit)
    @unit = unit
    @today = Date.current
  end

  def perform!
    notify_missing_dates if notifiable_missing_dates.present?
    notify_incomplete_meetings if notifiable_incomplete_meetings.present?
  end

  private

  attr_reader :unit, :today

  def notify_missing_dates
    ::MissingMeetingsNotification.with(dates: notifiable_missing_dates).deliver(unit.users.meeting_schedulers)
  end

  def notify_incomplete_meetings
    notifiable_incomplete_meetings.each do |meeting|
      recipients = meeting.scheduler ? [meeting.scheduler] : unit.users.meeting_schedulers.to_a
      ::IncompleteMeetingNotification.with(meeting: meeting).deliver(recipients)
    end
  end

  def notifiable_missing_dates
    if today.saturday?
      missing_meeting_dates
    else
      missing_meeting_dates.select { |date| date == next_sunday }
    end
  end

  def notifiable_incomplete_meetings
    if today.saturday?
      incomplete_meetings
    else
      incomplete_meetings.select { |meeting| meeting.date == next_sunday }
    end
  end

  def missing_meeting_dates
    expected_meeting_dates - existing_meetings.map(&:date)
  end

  def incomplete_meetings
    existing_meetings.select(&:not_fully_scheduled?)
  end

  def existing_meetings
    @existing_meetings ||= unit.meetings.occurring_after(today).occurring_on_or_before(outside_check_date).to_a
  end

  def outside_check_date
    expected_meeting_dates.last
  end

  def expected_meeting_dates
    [
      next_sunday,
      next_sunday + 7.days,
      next_sunday + 14.days,
      next_sunday + 21.days,
    ]
  end

  def next_sunday
    @next_sunday ||= today.next_occurring(:sunday)
  end
end
