module Meetings
  # What API and MCP clients see of a meeting: what every role already sees on the meetings page (its type, the
  # people taking part by name, its talks and its songs). Never member ids, the scheduler, contact details or notes.
  module ApiJson
    module_function

    # For a list of meetings.
    # @param meeting [Meeting] with talks loaded
    # @return [Hash]
    def summary(meeting)
      {
        date: meeting.date,
        meeting_type: meeting.meeting_type,
        speakers: meeting.talks.map(&:speaker_name),
      }
    end

    # For one meeting.
    # @param meeting [Meeting]
    # @return [Hash]
    def detail(meeting)
      {
        date: meeting.date,
        meeting_type: meeting.meeting_type,
        contributors: contributors(meeting),
        talks: meeting.talks.map { |talk| talk_json(talk) },
        songs: meeting.songs.default_order.map { |song| song_json(song) },
      }
    end

    # @return [Hash] presider, conductor, chorister, organist, opening_prayer and closing_prayer, each a name or nil
    def contributors(meeting)
      ::Meeting::CONTRIBUTOR_TITLES.keys.to_h do |attribute|
        [attribute.to_s.delete_suffix("_name").to_sym, meeting.public_send(attribute)]
      end
    end

    def talk_json(talk)
      {
        position: talk.position,
        speaker: talk.speaker_name,
        purpose: talk.purpose,
        topic: talk.topic,
      }
    end

    def song_json(song)
      {
        song_type: song.song_type,
        title: song.title,
      }
    end
  end
end
