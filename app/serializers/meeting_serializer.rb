# One meeting in full: what every role already sees on the meetings page (its type, the people taking part by name,
# its talks and its songs). Never member ids, the scheduler, contact details or notes. See docs/api.md.
class MeetingSerializer
  # @param meeting [Meeting]
  # @return [Hash]
  def self.call(meeting)
    {
      date: meeting.date,
      meeting_type: meeting.meeting_type,
      contributors: contributors(meeting),
      talks: meeting.talks.map { |talk| ::TalkSerializer.call(talk) },
      songs: meeting.songs.default_order.map { |song| ::SongSerializer.call(song) },
    }
  end

  # @return [Hash] presider, conductor, chorister, organist, opening_prayer and closing_prayer, each a name or nil
  def self.contributors(meeting)
    ::Meeting::CONTRIBUTOR_TITLES.keys.to_h do |attribute|
      [attribute.to_s.delete_suffix("_name").to_sym, meeting.public_send(attribute)]
    end
  end
  private_class_method :contributors
end
