require "rails_helper"
require "edify/hymns"

describe ::Edify::Hymns do
  let(:raw_lines) { ::Rails.root.join("lib/edify/db/hymns.txt").readlines(chomp: true) }
  let(:database) { described_class.database }
  let(:numbers) { database.map(&:first) }

  describe "hymns.txt" do
    it "has a tab-separated title and number on every line" do
      expect(raw_lines).to all(match(/\A[^\t]+\t\d+\z/))
    end

    it "has no duplicate hymn numbers" do
      duplicates = numbers.tally.select { |_number, count| count > 1 }.keys
      expect(duplicates).to be_empty
    end
  end

  describe ".database" do
    it "contains one entry per line in hymns.txt" do
      expect(database.size).to eq(raw_lines.size)
    end

    it "is sorted by hymn number" do
      expect(numbers).to eq(numbers.sort)
    end

    it "has a positive integer number and a non-blank title for every entry" do
      database.each do |number, title|
        expect(number).to be_a(::Integer).and(be_positive)
        expect(title).to be_present
      end
    end

    it "includes a hymn from the original hymnbook" do
      expect(database).to include([1, "The Morning Breaks"])
    end

    it "includes a hymn from Hymns—For Home and Church" do
      expect(database).to include([1072, "When I Survey the Wondrous Cross"])
    end
  end

  describe ".datalist" do
    let(:datalist) { described_class.datalist }

    it "renders one option per hymn" do
      expect(datalist.scan("<option").size).to eq(database.size)
    end

    it "formats each option value as title and number" do
      expect(datalist).to include('<option value="The Morning Breaks #1">')
    end

    it "escapes titles for HTML" do
      expect(datalist).to include('<option value="It&#39;s Joyful to Live the Gospel #1067">')
    end

    it "is html safe" do
      expect(datalist).to be_html_safe
    end
  end
end
