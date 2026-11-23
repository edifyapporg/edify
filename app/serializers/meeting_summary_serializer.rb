# A meeting in a list of meetings: its date, type and speakers. See MeetingSerializer for one meeting in full, and
# docs/api.md.
class MeetingSummarySerializer
  # @param meeting [Meeting] with talks loaded
  # @return [Hash]
  def self.call(meeting)
    {
      date: meeting.date,
      meeting_type: meeting.meeting_type,
      speakers: meeting.talks.map(&:speaker_name),
    }
  end
end
