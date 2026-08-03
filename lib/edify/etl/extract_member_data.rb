module Edify
  module Etl
    class ExtractMemberData
      ATTRIBUTE_NAME_MAP = {
        "Name" => "name",
        "Gender" => "gender",
        "Birth Date" => "birthdate",
        "Phone Number" => "phone_number",
        "E-mail" => "email",
      }.freeze

      # Header labels that appear in the export but aren't imported. They must
      # still be recognised so their column position is accounted for when
      # aligning data cells to headers.
      IGNORED_HEADER_LABELS = ["Age"].freeze

      FILTERED_DATA_REGEX = /\(filtered from \d+ total\)/
      MEMBER_DATA_REGEX = /\A.*(^\t*Name.*)^Count:/m
      UNBAPTIZED_MEMBER_OF_RECORD_REGEX = /\A[*\s]*(.*)\z/

      def self.perform(import_job)
        new(import_job).perform
      end

      def initialize(import_job)
        @import_job = import_job
        @raw_member_rows = []
      end

      def perform
        download_member_data
        check_for_filter_text if errors.empty?
        strip_raw_data if errors.empty?
        extract_headers if errors.empty?
        extract_members if errors.empty?

        raw_member_rows
      end

      private

      attr_reader :import_job, :raw_member_rows
      attr_accessor :raw_data

      delegate :errors, to: :import_job, private: true

      def download_member_data
        self.raw_data = import_job.raw_data.download
        errors.add(:raw_data, "was not provided") if raw_data.blank?
      end

      def check_for_filter_text
        return unless raw_data =~ FILTERED_DATA_REGEX

        message = "has been filtered. Please ensure you have scrolled to the bottom of the member list before copying."
        errors.add(:raw_data, message)
      end

      def strip_raw_data
        self.raw_data = raw_data[MEMBER_DATA_REGEX, 1]
        return if raw_data.present?

        errors.add(:raw_data, "could not be parsed. Please ensure you have copy/pasted the entire member list.")
      end

      # Content lines of the member list with blank lines removed. Exports
      # separate records with blank lines, and newer exports also put each
      # header cell on its own line, so we normalise by dropping blanks first.
      def content_lines
        @content_lines ||= raw_data.lines.map(&:chomp).compact_blank
      end

      # Reads the leading header cells, which may be laid out either as a single
      # tab-separated row (older exports) or one cell per line (newer exports).
      # Both collapse to the same ordered list of column headers, keyed by the
      # data attribute each column maps to. Unrecognised-but-expected headers
      # (e.g. Age) are retained so data cells stay aligned to their columns.
      def extract_headers
        header_labels = []

        content_lines.each do |line|
          cells = line.split("\t").map(&:strip).compact_blank
          break unless header_cells?(cells)

          header_labels.concat(cells)
          @data_line_offset = (@data_line_offset || 0) + 1
        end

        @headers = header_labels.map { |label| ATTRIBUTE_NAME_MAP.fetch(label, label) }

        ATTRIBUTE_NAME_MAP.each do |header_name, attribute_name|
          next if @headers.include?(attribute_name)

          errors.add(:raw_data, "did not contain expected header #{header_name}")
        end
      end

      def header_cells?(cells)
        cells.any? &&
          cells.all? { |cell| ATTRIBUTE_NAME_MAP.key?(cell) || IGNORED_HEADER_LABELS.include?(cell) }
      end

      def extract_members
        import_job.update(status_text: "Parsing member list")

        records = member_records
        import_job.update(row_count: records.size)

        records.each.with_index(1) do |cells, row_index|
          attributes = @headers.zip(cells).to_h.slice(*included_attributes)
          next if attributes.compact.empty?

          raw_member_row = RawMemberRow.new(**attributes)

          strip_unbaptized_member_of_record(raw_member_row)

          raw_member_rows << raw_member_row
          import_job.increment!(:succeeded_count)
        rescue StandardError => e
          errors.add(:base, "Extraction error at row #{row_index}: #{e}")
          import_job.increment!(:failed_count)
        ensure
          import_job.set_elapsed_time!
        end
      end

      # Groups the data lines into one cell array per member. A member's cells
      # usually sit on a single tab-separated line, but newer exports wrap
      # unbaptized members across several lines: the name, a status annotation
      # (e.g. "Not Baptized"), then the remaining columns. A line beginning with
      # a "Last, First" name starts a new record; single-cell annotation lines
      # are dropped; any other line continues the current record.
      def member_records
        content_lines.drop(@data_line_offset.to_i).each_with_object([]) do |line, records|
          cells = line.split("\t")
          cells.shift while cells.first == "" # drop the leading empty column older exports include
          next if cells.empty?

          if member_name?(cells.first)
            records << cells
          elsif cells.length > 1 && records.any?
            records.last.concat(cells) # continuation columns for a wrapped record
          end
          # otherwise a single-cell annotation line (e.g. "Not Baptized") — skip
        end
      end

      def member_name?(value)
        value.include?(",")
      end

      def included_attributes
        # Struct#members returns an array of symbols representing the attributes of the Struct,
        # e.g., [:name, :gender, :birthdate], similar to calling `.to_h.keys` on the Struct.
        # It has nothing to do with the Member model
        @included_attributes ||= RawMemberRow.members.map(&:to_s)
      end

      def strip_unbaptized_member_of_record(raw_member_row)
        return if raw_member_row.name.blank?

        raw_member_row.name = raw_member_row.name.match(UNBAPTIZED_MEMBER_OF_RECORD_REGEX)[1]
      end
    end
  end
end
