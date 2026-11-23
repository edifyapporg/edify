require "rails_helper"

RSpec.describe ::SongSerializer do
  it "gives song type and title" do
    song = ::Song.new(song_type: :sacrament_hymn, title: "I Stand All Amazed #193")
    expect(described_class.call(song)).to eq(song_type: "sacrament_hymn", title: "I Stand All Amazed #193")
  end
end
