# A talk in a list of talks: the meeting's date, the speaker's name, purpose and topic. Never the linked member's id
# or record. See TalkSerializer for a talk within its meeting, and docs/api.md.
class TalkSummarySerializer
  # @param talk [Talk] with its meeting loaded
  # @return [Hash]
  def self.call(talk)
    {
      date: talk.date,
      speaker: talk.speaker_name,
      purpose: talk.purpose,
      topic: talk.topic,
    }
  end
end
