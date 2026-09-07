class Member < ApplicationRecord
  # The youngest anyone can be and still appear in the list of potential speakers. Eight is the floor we
  # chose; baptism is not part of the test.
  MINIMUM_SPEAKER_AGE = 8
  # The age at which a child joins the youth programs: January of the year they turn twelve.
  YOUTH_AGE = 12
  # The age at which someone is spoken to as an adult rather than a youth.
  ADULT_AGE = 18

  has_many :talks, dependent: :nullify
  has_many :notes, dependent: :destroy
  belongs_to :unit

  enum :gender, { male: 0, female: 1 }

  validates :name, :gender, :birthdate, presence: true
  validates :name, uniqueness: { scope: :birthdate }, if: :name?
  validate :validate_age

  strip_attributes

  scope :alphabetized, -> { order(:name) }
  scope :with_last_talk_date, lambda {
    from(left_joins(talks: :meeting)
           .select("distinct on (members.id) members.*, meetings.date as last_talk_date")
           .order("members.id, meetings.date desc"), :members)
  }

  after_save_commit :match_talks

  def self.ransackable_attributes(_auth_object = nil)
    %w[birthdate gender last_talk_date name synced_on]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[]
  end

  # @return [Integer]
  def age
    (Date.current - birthdate).to_i / 365
  end

  # @return [String (frozen)]
  def bio
    "#{gender.titleize}, #{age}"
  end

  # @return [Boolean]
  def created_on_first_sync?
    created_at.to_date == unit.first_synced_on
  end

  # @return [Date, nil]
  def last_talk_date
    return attributes["last_talk_date"] if attributes.key?("last_talk_date")

    talks.joins(:meeting).maximum("meetings.date")&.to_date
  end

  # @return [Boolean]
  def new_member?
    time_in_unit.present? && time_in_unit < 1.year
  end

  # @return [Boolean]
  def not_in_most_recent_sync?
    synced_on.nil? || (synced_on < unit.last_synced_on)
  end

  # @return [Boolean]
  def paused?
    paused_until? && paused_until > Date.current
  end

  # @return [ActiveSupport::Duration]
  def time_in_unit
    return @time_in_unit if defined?(@time_in_unit)
    # If member was created on the first sync, we don't know how long they have been a member of the unit
    return @time_in_unit = nil if created_on_first_sync?

    @time_in_unit = (Date.current - created_at.to_date).to_i.days
  end

  # Too young to be offered as a speaker, and so not worth storing. Age is the only test: a child of eight
  # can be invited to speak whether or not they have been baptized.
  # @return [Boolean]
  def under_age?
    birthdate.present? && birthdate > MINIMUM_SPEAKER_AGE.years.ago.to_date
  end

  # Which of the three groups a speaker is invited and prepared as. Each is asked to speak for a different
  # length and gets its own wording.
  # @return [Symbol] :child, :youth or :adult
  def speaker_category
    return :child if child?
    return :youth if youth?

    :adult
  end

  # @return [Boolean] not yet old enough for the youth programs, which a child joins in the year they turn 12
  def child?
    birthdate.present? && birthdate >= (YOUTH_AGE - 1).years.ago.beginning_of_year.to_date
  end

  # @return [Boolean]
  def youth?
    birthdate.present? && !child? && birthdate >= (ADULT_AGE - 1).years.ago.beginning_of_year.to_date
  end

  private

  def match_talks
    talks = unit.talks.where(speaker_name: name, member_id: nil)
    talks.update_all(member_id: id)
  end

  def validate_age
    return unless under_age?

    errors.add(:birthdate, "member is not old enough")
  end
end
