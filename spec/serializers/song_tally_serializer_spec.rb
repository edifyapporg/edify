require "rails_helper"

RSpec.describe ::SongTallySerializer do
  it "gives title, times sung, last sung and song types" do
    tally = ::Songs::RecentlySung::Tally.new(title: "Abide with Me #166", times_sung: 2,
                                             last_sung: Date.new(2026, 5, 31), song_types: ["closing_hymn"])

    expect(described_class.call(tally)).to eq(title: "Abide with Me #166", times_sung: 2,
                                              last_sung: Date.new(2026, 5, 31), song_types: ["closing_hymn"])
  end
end
