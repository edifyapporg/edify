# One hymn's tally in a list of recently sung songs (Songs::RecentlySung). See docs/api.md.
class SongTallySerializer
  # @param tally [Songs::RecentlySung::Tally]
  # @return [Hash]
  def self.call(tally)
    {
      title: tally.title,
      times_sung: tally.times_sung,
      last_sung: tally.last_sung,
      song_types: tally.song_types,
    }
  end
end
