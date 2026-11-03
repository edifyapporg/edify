class ImportJob < ApplicationRecord
  belongs_to :owner, class_name: "User", optional: true
  belongs_to :unit
  has_one_attached :raw_data
  broadcasts_to :unit, inserts_by: :prepend

  scope :most_recent_first, -> { reorder(created_at: :desc) }

  attribute :row_count, default: 0
  attribute :succeeded_count, default: 0
  attribute :failed_count, default: 0
  attribute :ignored_count, default: 0

  # Which of the two Member Directory tabs the pasted data came from.
  enum :kind, { individuals: 0, households: 1 }, default: :individuals

  enum :status, {
    waiting: 0,
    extracting: 1,
    transforming: 2,
    loading: 3,
    finished: 4,
    failed: 5
  }

  def data_string=(string)
    @data_string = string

    raw_data.attach(
      io: StringIO.new(string),
      filename: "raw_data.txt",
      content_type: "text/plain"
    )
  end

  def data_string
    return @data_string if defined?(@data_string)

    # Active Storage hands a download back as binary. The directory is UTF-8, and a binary string never
    # compares equal to the UTF-8 one the database returns for the same bytes -- nor can it be
    # transliterated, which duplicate detection relies on.
    @data_string = raw_data.download&.force_encoding(Encoding::UTF_8)
  end

  # A regular update with callbacks will wipe out errors on the ImportJob object.
  # Use update_column to keep errors intact.
  def log!(value)
    new_logs = "#{logs}#{value}\n"
    update_column(:logs, new_logs)
  end

  def owner_first_name
    owner&.first_name || "Unknown"
  end

  # @return [Array[<String>]]
  def parsed_errors
    JSON.parse(error_message || "[\"None\"]")
  end

  # A regular update with callbacks will wipe out errors on the ImportJob object.
  # Use update_column to keep errors intact.
  def set_elapsed_time!
    return unless persisted? && started_at.present?

    update_column(:elapsed_seconds, ::Time.current - started_at)
  end

  # A regular update with callbacks will wipe out errors on the ImportJob object.
  # Use update_column to keep errors intact.
  def start!
    update_column(:started_at, ::Time.current)
  end
end
