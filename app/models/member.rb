class Member < ApplicationRecord
  # The youngest anyone can be and still appear in the list of potential speakers. Eight is the floor we
  # chose; baptism is not part of the test.
  MINIMUM_SPEAKER_AGE = 8
  # The age at which a child joins the youth programs: January of the year they turn twelve.
  YOUTH_AGE = 12
  # The age at which someone is spoken to as an adult rather than a youth.
  ADULT_AGE = 18
  # What the API, MCP tools and leaders call each speaker category: "primary", not "child".
  AGE_GROUPS = { child: "primary", youth: "youth", adult: "adult" }.freeze
  # Limits on a name search, shared by the API and the MCP tools.
  SEARCH_QUERY_LENGTH = (2..100)
  SEARCH_DEFAULT_LIMIT = 25
  SEARCH_LIMIT_RANGE = (1..100)

  has_many :talks, dependent: :nullify
  has_many :notes, dependent: :destroy
  has_many :household_members, dependent: :nullify, inverse_of: :member
  has_many :households, through: :household_members
  belongs_to :unit

  enum :gender, { male: 0, female: 1 }

  # A full birthdate, accepted from the importer and the JSON upsert but never stored. Assigning one sets
  # `birth_year` and lets #under_age? check the exact date. Blank leaves `birth_year` as it was.
  attribute :birthdate, :date

  validates :name, :gender, :birth_year, presence: true
  validates :birth_year, numericality: { only_integer: true, greater_than_or_equal_to: 1900,
                                         less_than_or_equal_to: -> { Date.current.year } },
                         allow_nil: true
  validates :name, uniqueness: { scope: [:unit_id, :birth_year] }, if: :name?
  validate :validate_age

  strip_attributes

  scope :alphabetized, -> { order(:name) }
  # Members whose name contains every word of the query (see ApplicationRecord.matching_every_word).
  scope :matching_name, ->(query) { matching_every_word(:name, query) }
  scope :synced_since, ->(date) { where(synced_on: date..) }
  scope :with_last_talk_date, lambda {
    from(left_joins(talks: :meeting)
           .select("distinct on (members.id) members.*, meetings.date as last_talk_date")
           .order("members.id, meetings.date desc"), :members)
  }

  after_save_commit :match_talks, :match_household_members

  # Members in one speaker category, matching #speaker_category but filtered in SQL. Both use the same birth-year
  # cutoffs, so they cannot drift apart. A member with no birth year counts as an adult, as #speaker_category has it.
  # @param category [Symbol] :child, :youth or :adult
  scope :in_speaker_category, lambda { |category|
    case category
    when :child then where(birth_year: earliest_child_birth_year..)
    when :youth then where(birth_year: earliest_youth_birth_year...earliest_child_birth_year)
    when :adult then where(birth_year: nil).or(where(birth_year: ...earliest_youth_birth_year))
    else raise ArgumentError, "unknown speaker category: #{category.inspect}"
    end
  }

  # Anyone born in or after this year is a child: they join the youth programs in January of the year they turn 12.
  # @return [Integer]
  def self.earliest_child_birth_year
    Date.current.year - (YOUTH_AGE - 1)
  end

  # Anyone born in or after this year, and not a child, is a youth: they are spoken to as an adult from January of the
  # year they turn 18.
  # @return [Integer]
  def self.earliest_youth_birth_year
    Date.current.year - (ADULT_AGE - 1)
  end

  # The year of a birthdate given as text or a Date, cast the way the birthdate attribute casts it.
  # @return [Integer, nil]
  def self.birth_year_from(value)
    ::ActiveModel::Type::Date.new.cast(value)&.year
  end

  def self.ransackable_attributes(_auth_object = nil)
    %w[baptized birth_year gender last_talk_date name synced_on]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[]
  end

  # The age the member turns this calendar year. Only the birth year is stored, so their exact age is unknown.
  # @return [Integer, nil]
  def age_this_year
    birth_year && (Date.current.year - birth_year)
  end

  # @return [String] e.g. "Female, turns 35 this year"
  def bio
    return gender.to_s.titleize if birth_year.nil?

    "#{gender.to_s.titleize}, turns #{age_this_year} this year"
  end

  # Keeps the year of any full birthdate assigned, and leaves `birth_year` alone when it is blank.
  def birthdate=(value)
    super
    self.birth_year = birthdate.year if birthdate
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
    return false if unit.last_synced_on.blank? # a unit that has never imported has nothing to be missing from

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
  # can be invited to speak whether or not they have been baptized. The import has a full birthdate and checks it
  # exactly. The member forms ask only for a birth year, so there the test is turning eight this year or earlier.
  # @return [Boolean]
  def under_age?
    return birthdate > MINIMUM_SPEAKER_AGE.years.ago.to_date if birthdate.present?

    birth_year.present? && age_this_year < MINIMUM_SPEAKER_AGE
  end

  # The speaker category as clients name it.
  # @return [String] "primary", "youth" or "adult"
  def age_group
    AGE_GROUPS.fetch(speaker_category)
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
    birth_year.present? && birth_year >= self.class.earliest_child_birth_year
  end

  # @return [Boolean]
  def youth?
    birth_year.present? && !child? && birth_year >= self.class.earliest_youth_birth_year
  end

  # The adults of the household, whom a child or youth is invited alongside.
  # @return [Array<Member>]
  def parents
    households.flat_map { |household| household.parents.filter_map(&:member) }.uniq - [self]
  end

  private

  def match_talks
    talks = unit.talks.where(speaker_name: name, member_id: nil)
    talks.update_all(member_id: id)
  end

  # The household directory is imported separately and may name someone before their member record
  # exists, or after it was merged away. Claiming the entry on save keeps the two halves together
  # without waiting for the next import.
  #
  # Where the unit has two members of one name no link can be trusted, so any existing one is released
  # rather than left pointing at whichever record happened to be saved first -- attaching a household
  # to the wrong person is worse than leaving it unattached, and the importer draws the same line.
  # Merging the duplicate away saves the survivor, which claims the entry back.
  def match_household_members
    entries = HouseholdMember.where(household: unit.households, name: name)
    namesakes = unit.members.where(name: name)

    if namesakes.many?
      entries.where(member_id: namesakes.select(:id)).update_all(member_id: nil)
    else
      entries.unmatched.update_all(member_id: id)
    end
  end

  def validate_age
    return unless under_age?

    errors.add(birthdate.present? ? :birthdate : :birth_year, "member is not old enough")
  end
end
