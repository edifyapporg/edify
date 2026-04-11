class Meeting < ApplicationRecord
  CONTRIBUTOR_TITLES = {
    presider_name: "Presiding",
    conductor_name: "Conducting",
    chorister_name: "Chorister",
    organist_name: "Organist",
    opening_prayer_name: "Opening Prayer",
    closing_prayer_name: "Closing Prayer",
  }.freeze

  has_many :talks, -> { order(position: :asc) }, dependent: nil
  has_many :songs, dependent: :destroy
  belongs_to :unit
  belongs_to :scheduler, class_name: "User", optional: true

  has_noticed_notifications param_name: :meeting

  enum :meeting_type, {
    sacrament_meeting: 0,
    testimony_meeting: 1,
    ward_conference: 2,
    stake_conference: 3,
    general_conference: 4,
    primary_program: 5,
    musical_testimony: 6,
  }

  validates :meeting_type, :date, presence: true
  validates :date, uniqueness: { scope: :unit, message: I18n.t("models.meeting.date_not_unique") }, if: :date?

  strip_attributes

  scope :future, -> { occurring_after(Date.current) }
  scope :most_recent_first, -> { order(date: :desc) }
  scope :occurring_after, ->(date) { where("date > ?", date) }
  scope :occurring_on_or_after, ->(date) { where(date: date..) }
  scope :occurring_on_or_before, ->(date) { where(date: ..date) }
  scope :oldest_first, -> { order(date: :asc) }

  def self.ransackable_attributes(_auth_object = nil)
    %w[date meeting_type]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[]
  end

  def not_fully_scheduled?
    status != :ok
  end

  def not_yet_occurred?
    date >= Date.current
  end

  def status
    case meeting_type.to_sym
    when :sacrament_meeting || :ward_conference
      sacrament_status
    else
      :ok
    end
  end

  def sacrament_status
    if talk_count.zero?
      :empty
    elsif talk_count < 3
      :incomplete
    else
      :ok
    end
  end

  def talk_count
    @talk_count ||= talks.size
  end

  def unit_members
    @unit_members ||= unit.members
  end
end
