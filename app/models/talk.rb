class Talk < ApplicationRecord
  # Limits on listing talks, shared by the API and the MCP tools.
  LISTING_DEFAULT_LIMIT = 50
  LISTING_LIMIT_RANGE = (1..200)
  FILTER_TEXT_LENGTH = (2..100)

  DEFAULT_PURPOSE_LIST = [
    "Calling Change",
    "Departing College Student",
    "Departing Missionary",
    "New Ward Member",
    "Returning Missionary",
    "Stake Representative",
    "Ward Conference",
    "Youth Speaker",
  ].freeze

  belongs_to :meeting
  belongs_to :member, optional: true
  has_one :unit, through: :meeting
  acts_as_list scope: :meeting

  validates :speaker_name, presence: true

  strip_attributes

  scope :sort_by_meeting_date_asc, -> { joins(:meeting).order("meetings.date asc") }
  scope :sort_by_meeting_date_desc, -> { joins(:meeting).order("meetings.date desc") }
  # Talks whose speaker name contains every word of the query (see ApplicationRecord.matching_every_word).
  scope :speaker_matching, ->(query) { matching_every_word(:speaker_name, query) }
  # Talks whose purpose contains the text, ignoring case: "missionary" finds "Departing Missionary".
  scope :purpose_containing, lambda { |text|
    where(arel_table[:purpose].matches("%#{sanitize_sql_like(text.to_s.squish)}%", nil, false))
  }

  # Talks narrowed by any of these filters, newest meeting first and in program order within a meeting, with their
  # meetings loaded. Shared by the API's talks list and the list_talks MCP tool; call it on a unit's talks.
  # @param speaker [String, nil] every word must appear in the speaker name
  # @param purpose [String, nil] contained in the purpose, ignoring case
  # @param from [Date, nil] first meeting date, inclusive
  # @param to [Date, nil] last meeting date, inclusive
  # @return [ActiveRecord::Relation]
  def self.filtered(speaker: nil, purpose: nil, from: nil, to: nil)
    relation = unscope(:order).includes(:meeting)
    relation = relation.speaker_matching(speaker) if speaker
    relation = relation.purpose_containing(purpose) if purpose
    relation = relation.where(meetings: { date: from.. }) if from
    relation = relation.where(meetings: { date: ..to }) if to
    relation.reorder(::Meeting.arel_table[:date].desc, arel_table[:position].asc)
  end

  before_save :match_member

  delegate :date, :date?, to: :meeting, allow_nil: true

  def self.ransackable_attributes(_auth_object = nil)
    %w[purpose speaker_name topic member_id]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[]
  end

  # @return [ActiveSupport::Duration, nil]
  def duration_since_previously_spoke
    previous_talk = unit.speaker_last_talk(speaker_name, meeting_date)

    (meeting_date - previous_talk.meeting_date).to_i.days if previous_talk.present?
  end

  def meeting_date
    meeting.date
  end

  def member_name
    member&.name
  end

  def topic_truncated
    return if topic.blank?
    return topic if topic.length <= 50

    "#{topic.first(50)}..."
  end

  def unit_members
    meeting.unit.members
  end

  private

  def match_member
    return if meeting.nil?

    self.member_id = unit_members.where(name: speaker_name).first&.id
  end
end
