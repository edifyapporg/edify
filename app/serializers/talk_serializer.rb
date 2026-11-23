# A talk within a meeting: its place in the program, the speaker's name, purpose and topic. Never the linked member's
# id or record. See docs/api.md.
class TalkSerializer
  # @param talk [Talk]
  # @return [Hash]
  def self.call(talk)
    {
      position: talk.position,
      speaker: talk.speaker_name,
      purpose: talk.purpose,
      topic: talk.topic,
    }
  end
end
