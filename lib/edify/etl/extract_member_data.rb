require "csv"

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
        morph_header_row if errors.empty?
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

      def morph_header_row
        lines = raw_data.lines
        header = lines.shift

        # Rename headers by matching whole tab-delimited fields rather than
        # substrings, so an expected header like "Name" can't be picked up
        # inside a different column (e.g. "Preferred Name") and leave the real
        # column unmapped.
        fields = header.chomp.split("\t")
        fields.map! { |field| ATTRIBUTE_NAME_MAP.fetch(field.strip, field) }

        ATTRIBUTE_NAME_MAP.each do |header_name, attribute_name|
          next if fields.include?(attribute_name)

          errors.add(:raw_data, "did not contain expected header #{header_name}")
        end

        lines.unshift("#{fields.join("\t")}\n")
        self.raw_data = lines.join
      end

      def extract_members
        import_job.update(status_text: "Parsing member list")

        member_list_rows = CSV.parse(raw_data, headers: true, col_sep: "\t", encoding: "UTF-8")

        import_job.update(row_count: member_list_rows.size)
        member_list_rows.each.with_index(1) do |row, row_index|
          attributes = row.to_h.slice(*included_attributes)
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

      def included_attributes
        # Struct#members returns an array of symbols representing the attributes of the Struct,
        # e.g., [:name, :gender, :birthdate], similar to calling `.to_h.keys` on the Struct.
        # It has nothing to do with the Member model
        @included_attributes ||= RawMemberRow.members.map(&:to_s)
      end

      def strip_unbaptized_member_of_record(raw_member_row)
        stripped_name = raw_member_row.name.match(UNBAPTIZED_MEMBER_OF_RECORD_REGEX)[1]
        raw_member_row.name = stripped_name
      end
    end
  end
end
