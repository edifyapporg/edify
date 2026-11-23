# A song within a meeting: its place in the program and its title. See docs/api.md.
class SongSerializer
  # @param song [Song]
  # @return [Hash]
  def self.call(song)
    {
      song_type: song.song_type,
      title: song.title,
    }
  end
end
