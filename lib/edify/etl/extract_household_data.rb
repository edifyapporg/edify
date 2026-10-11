module Edify
  module Etl
    # Parses the Households tab of the member directory, which is laid out quite differently from the Individuals tab:
    # each household is a block of lines separated from the next by a blank line, and only the phone number and email
    # address are tab-separated. The rest -- the people, then the address -- are plain lines that have to be told
    # apart by what they look like.
    #
    # The household directory carries no gender and no birthdate, so it can never create a Member. It gives the
    # household's shared contact details and, crucially, who lives with whom.
    class ExtractHouseholdData
      HOUSEHOLD_DATA_REGEX = /\A.*(^\t*Name.*)^Count:/m
      FILTERED_DATA_REGEX = /\(filtered from \d+ total\)/
      HEADER_LABELS = ["Name", "Household Members", "Address", "Phone Number", "E-mail"].freeze

      # The last line of an address is a city, a two-letter state and a ZIP; a few records give only a state.
      CITY_STATE_ZIP_REGEX = /\b[A-Za-z]{2}\s+\d{5}(-\d{4})?\s*\z/
      STATE_ONLY_REGEX = /\A[A-Z][a-z]+\z/
      STREET_REGEX = /\A(\d|PO Box|P\.O\.)/i
      # The word boundary matters: without it "Ste" swallows "Steve" and "Stephanie".
      SECONDARY_ADDRESS_REGEX = /\A(Apt|Apartment|Unit|Ste|Suite|#)\b/i
      # A phone number is digits and punctuation only, which an address line never is.
      PHONE_REGEX = /\A[\d\s().+-]+\z/

      # A listed age follows the name in parentheses: "Luke (14)".
      LISTED_AGE_REGEX = /\A(.*?)\s+\((\d+)\)\z/
      # Status notes the directory puts on their own line, the way the Individuals tab does with "Not Baptized".
      ENTRY_ANNOTATIONS = ["Out-of-Unit"].freeze

      def self.perform(import_job)
        new(import_job).perform
      end

      def initialize(import_job)
        @import_job = import_job
        @raw_households = []
      end

      def perform
        download_household_data
        check_for_filter_text if errors.empty?
        strip_raw_data if errors.empty?
        check_for_headers if errors.empty?
        extract_households if errors.empty?

        raw_households
      end

      private

      attr_reader :import_job, :raw_households
      attr_accessor :raw_data

      delegate :errors, to: :import_job, private: true

      def download_household_data
        self.raw_data = import_job.data_string
        errors.add(:raw_data, "was not provided") if raw_data.blank?
      end

      def check_for_filter_text
        return unless raw_data =~ FILTERED_DATA_REGEX

        message = "has been filtered. Please ensure you have scrolled to the bottom of the household list before " \
                  "copying."
        errors.add(:raw_data, message)
      end

      def strip_raw_data
        self.raw_data = raw_data[HOUSEHOLD_DATA_REGEX, 1]
        return if raw_data.present?

        errors.add(:raw_data, "could not be parsed. Please ensure you have copy/pasted the entire household list.")
      end

      # The two header lines are "Name" on its own and then the remaining four column labels tab-separated. Checking
      # them catches someone pasting the Individuals tab into the household import.
      def check_for_headers
        labels = raw_data.lines.first(2).flat_map { |line| line.split("\t") }.map(&:strip).compact_blank

        return if HEADER_LABELS.all? { |label| labels.include?(label) }

        errors.add(:raw_data, "did not look like the Households tab of the member directory. Please make sure you " \
                              "are on the Households tab before copying.")
      end

      def extract_households
        import_job.update(status_text: "Parsing household list")

        blocks = household_blocks
        import_job.update(row_count: blocks.size)

        blocks.each.with_index(1) do |block, row_index|
          raw_households << build_household(block)
          import_job.increment!(:succeeded_count)
        rescue StandardError => e
          errors.add(:base, "Extraction error at row #{row_index}: #{e}")
          import_job.increment!(:failed_count)
        ensure
          import_job.set_elapsed_time!
        end
      end

      # Households are separated by blank lines, so unlike the Individuals tab the blanks are meaningful and cannot be
      # stripped up front.
      def household_blocks
        lines = raw_data.lines.map(&:chomp).drop(header_line_count)
        lines = lines.take_while { |line| !line.start_with?("Count:") }

        lines.slice_when { |_previous, line| line.strip.empty? }
             .map { |block| block.reject { |line| line.strip.empty? } }
             .reject(&:empty?)
      end

      def header_line_count
        2
      end

      def build_household(block)
        name = block.first.sub(/\t\z/, "").strip
        remainder = block[1..]
        phone_number, email, remainder = split_contact(remainder)
        entry_lines, address_lines = split_entries_and_address(remainder)

        RawHousehold.new(name, address_lines, phone_number, email, build_entries(name, entry_lines))
      end

      # The contact line is last and is the only tab-separated line in the block. It is missing altogether for
      # households the directory has no phone number or email for, in which case the block ends with the address.
      def split_contact(lines)
        last = lines.last.to_s

        return [nil, nil, lines] unless contact_line?(last)

        if last.include?("\t")
          phone_number, email = last.split("\t", 2)
        elsif last.include?("@")
          email = last
        else
          phone_number = last
        end

        [phone_number.presence&.strip, email.presence&.strip, lines[0..-2]]
      end

      # Everything up to the address is a person. The address is found by anchoring on its city/state/ZIP line and
      # walking back over any street and apartment lines above it.
      def split_entries_and_address(lines)
        address_end = lines.rindex { |line| line.match?(CITY_STATE_ZIP_REGEX) }

        # A very few records carry only a state for an address, and it is the last line when they do.
        if address_end.nil?
          return [lines[0..-2], [lines.last]] if lines.many? && lines.last.match?(STATE_ONLY_REGEX)

          return [lines, []]
        end

        address_start = address_end
        address_start -= 1 while address_start.positive? && street_line?(lines[address_start - 1])

        [lines[0...address_start], lines[address_start..address_end]]
      end

      # A phone number, an email address, or both tab-separated -- never an address, whose ZIP+4 would
      # otherwise read as a phone number.
      def contact_line?(line)
        line.include?("\t") || line.include?("@") || (line.match?(PHONE_REGEX) && line.count("0-9") >= 7)
      end

      def street_line?(line)
        line.match?(STREET_REGEX) || line.match?(SECONDARY_ADDRESS_REGEX)
      end

      # People are listed by first name only unless their surname differs from the household's, so the household name
      # supplies the rest. The adults the household is named for are its parents.
      def build_entries(household_name, lines)
        surname = household_name.split(",").first.to_s.strip
        parent_names = parent_first_names(household_name)

        lines.filter_map do |line|
          next if ENTRY_ANNOTATIONS.include?(line)

          bare, listed_age = split_listed_age(line)
          full_name = bare.include?(",") ? bare : "#{surname}, #{bare}"
          given_name = bare.include?(",") ? bare.split(",", 2).last.strip : bare

          RawHouseholdEntry.new(full_name, listed_age, parent_names.include?(given_name))
        end
      end

      # "Adams, David & Erin" names David and Erin; "Allen, Toni" names only Toni.
      def parent_first_names(household_name)
        household_name.split(",", 2).last.to_s.split("&").map(&:strip).compact_blank
      end

      def split_listed_age(line)
        match = line.match(LISTED_AGE_REGEX)
        return [line.strip, nil] unless match

        [match[1].strip, match[2].to_i]
      end
    end
  end
end
