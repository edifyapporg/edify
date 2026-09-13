# Builds the pre-set messages a bishopric sends to a speaker -- the invitation to speak, guidance on preparing, and a
# reminder before the meeting -- along with the `sms:` and `mailto:` links that hand the finished message off to the
# device's messaging app. Edify never sends these itself; the links only pre-fill a draft for the user to review.
#
# The wording lives in config/locales/en.yml under `speaker_messages`. Each template is an ordered list of sentence
# segments per medium, and a segment whose interpolations are blank is dropped from the message. That is how one
# template covers a talk with a topic and a date as well as an invitation to a member who has neither yet.
#
# A segment key suffixed `_fallback` is the stand-in for the segment it is named after: it is used only when that
# segment was dropped, so a sentence that reads naturally with a date can still say something without one.
class SpeakerMessage
  TEMPLATES = %i[invitation guidance reminder].freeze
  SEGMENT_SEPARATORS = { email: "\n\n", sms: "\n" }.freeze
  INTERPOLATION_PATTERN = /%\{(\w+)\}/
  FALLBACK_SUFFIX = "_fallback".freeze

  class << self
    # @param [Talk] talk
    # @param [Symbol] template
    # @param [User, nil] sender
    # @param [Unit, nil] unit
    # @return [SpeakerMessage]
    def for_talk(talk, template:, sender: nil, unit: nil)
      new(
        template: template,
        member: talk.member,
        meeting_date: talk.date,
        purpose: talk.purpose,
        sender: sender,
        speaker_name: talk.speaker_name,
        topic: talk.topic,
        unit: unit || talk.meeting.unit,
      )
    end

    # @param [Member] member
    # @param [Symbol] template
    # @param [Date, nil] meeting_date
    # @param [User, nil] sender
    # @param [Unit, nil] unit
    # @return [SpeakerMessage]
    def for_member(member, template:, meeting_date: nil, sender: nil, unit: nil)
      new(
        template: template,
        member: member,
        meeting_date: meeting_date,
        sender: sender,
        speaker_name: member.name,
        unit: unit || member.unit,
      )
    end

    # @param [Symbol] template
    # @return [String]
    def label(template)
      I18n.t("speaker_messages.#{template}.label")
    end
  end

  # @param [Symbol] template
  # @param [Member, nil] member the recipient; without one there is no phone number or email to send to
  def initialize(template:, member: nil, meeting_date: nil, purpose: nil, sender: nil, speaker_name: nil, topic: nil,
                 unit: nil)
    @template = template.to_sym

    raise ArgumentError, "Unknown template: #{template}" unless @template.in?(TEMPLATES)

    @member = member
    @meeting_date = meeting_date
    @purpose = purpose
    @sender = sender
    @speaker_name = speaker_name
    @topic = topic
    @unit = unit
  end

  attr_reader :member, :template

  # @return [Boolean]
  def available?
    email_available? || sms_available?
  end

  # @return [Boolean]
  def email_available?
    email_recipients.any?
  end

  # Who the email is addressed to. A child's parents are written to about their child, so the parents are the
  # recipients; a youth is written to directly, with their parents copied. A youth with no email address of
  # their own is reached through their parents, who are then addressed rather than copied.
  # @return [Array<String>]
  def email_recipients
    addresses = case category
                when :child then [*parent_emails, member&.email]
                when :youth then member&.email.presence ? [member.email] : parent_emails
                else [member&.email]
                end

    addresses.compact_blank.uniq
  end

  # Copied rather than addressed: a youth's parents are told what their child has been asked to do.
  # @return [Array<String>]
  def email_copied
    return [] unless category == :youth

    parent_emails.compact_blank.uniq - email_recipients
  end

  # @return [String]
  def email_body
    body(:email)
  end

  # @return [String]
  def label
    self.class.label(template)
  end

  # @return [String, nil]
  def mailto_url
    return unless email_available?

    query = ["subject=#{encode(subject)}"]
    query << "cc=#{email_copied.join(',')}" if email_copied.any?
    query << "body=#{encode(email_body)}"

    "mailto:#{email_recipients.join(',')}?#{query.join('&')}"
  end

  # A child with no phone of their own is still reachable, because the text goes to their parents too.
  # @return [Boolean]
  def sms_available?
    sms_numbers.any?
  end

  # @return [String]
  def sms_body
    body(:sms)
  end

  # Everyone the text goes to. A child's parents are the ones being asked, and the child joins the thread when they
  # have a phone of their own; a youth is asked directly, with their parents on the thread as well. Comma-separated
  # recipients open a group message on iOS and on Android messaging apps that support it; one that does not falls
  # back to the first number rather than failing, so the person being addressed is listed first.
  # @return [Array<String>]
  def sms_numbers
    numbers = case category
              when :child then [*parent_phone_numbers, member&.phone_number]
              when :youth then [member&.phone_number, *parent_phone_numbers]
              else [member&.phone_number]
              end

    numbers.compact_blank.map { |number| normalize_number(number) }.uniq
  end

  # @return [String, nil]
  def sms_url
    return unless sms_available?

    # `?&body=` is the one separator both iOS and Android accept for a pre-filled message.
    "sms:#{sms_numbers.join(',')}?&body=#{encode(sms_body)}"
  end

  # @return [String, nil] the speaker's name as it is said aloud, rather than the way the roster sorts it
  def spoken_name
    [first_name, last_name].compact_blank.join(" ").presence
  end

  # @return [String]
  def subject
    I18n.t("speaker_messages.#{template}.subject")
  end

  private

  attr_reader :meeting_date, :purpose, :sender, :speaker_name, :topic, :unit

  # @param [Symbol] medium
  # @return [String]
  def body(medium)
    segments(medium).join(SEGMENT_SEPARATORS.fetch(medium))
  end

  # Which group's wording and speaking time to use. Without a member on record, or without their birthdate, we
  # cannot tell, so we treat them as an adult -- the longer talk is the safer thing to over-prepare for.
  # @return [Symbol]
  def category
    return :adult if member&.birthdate.blank?

    member.speaker_category
  end

  # @return [String]
  def speaking_time
    I18n.t("speaker_messages.defaults.speaking_time.#{category}")
  end

  # @return [Array<String>]
  def parent_phone_numbers
    parents.map(&:phone_number)
  end

  # @return [Array<String>]
  def parent_emails
    parents.map(&:email)
  end

  # How the message opens: the person being addressed. A child's parents are addressed together where there are two of
  # them -- "Brother and Sister Ngarupe" -- and everyone else is addressed by their own name.
  # @return [String, nil]
  def addressed_name
    return parents_name if category == :child && parents.any?

    [honorific, last_name].compact_blank.join(" ").presence
  end

  # "Brother and Sister Ngarupe" for two parents who share a surname, "Brother Dyches and Sister Bentley-Dyches" for
  # two who do not, and "Sister Kapitan" for one.
  # @return [String, nil]
  def parents_name
    named = parents.filter_map { |parent| [member_honorific(parent), surname_of(parent)] }
    return if named.empty?
    return named.first.compact_blank.join(" ").presence if named.one?

    honorifics = named.map(&:first)
    surnames = named.map(&:last)

    if surnames.uniq.one? && honorifics.compact.length == named.length
      "#{honorifics.join(' and ')} #{surnames.first}"
    else
      named.map { |pair| pair.compact_blank.join(" ") }.join(" and ")
    end
  end

  # @return [String, nil] the given names of the parents, for a sentence that speaks to them by first name
  def parents_first_names
    given = parents.filter_map { |parent| given_name_of(parent) }

    given.to_sentence if given.any?
  end

  # @return [Array<Member>]
  def parents
    @parents ||= member&.parents.to_a
  end

  # @param [String] text
  # @return [String]
  def encode(text)
    ERB::Util.url_encode(text)
  end

  # @param [Symbol] key
  # @return [Symbol, nil] the segment this one stands in for, when it is a fallback
  def fallback_for(key)
    base = key.to_s.delete_suffix(FALLBACK_SUFFIX)

    base.to_sym unless base == key.to_s
  end

  # Members are named "Last, First Middle", so the given name is what comes after the comma.
  # @return [String, nil]
  def first_name
    return if speaker_name.blank?

    surname, given_names = speaker_name.split(",", 2)

    (given_names.presence || surname).strip.split.first
  end

  # @return [String, nil]
  def formatted_meeting_date
    return if meeting_date.blank?

    I18n.l(meeting_date, format: :day_and_date)
  end

  # @return [String, nil]
  def honorific
    member_honorific(member)
  end

  # @param [Member, nil] person
  # @return [String, nil] nil when we do not know how to address them
  def member_honorific(person)
    return if person&.gender.blank?

    I18n.t("speaker_messages.defaults.honorific.#{person.gender}")
  end

  # The speaker in the third person, for a sentence addressed to their parents.
  # @return [String]
  def speaker_pronoun
    I18n.t("speaker_messages.defaults.pronoun.#{member&.gender.presence || :unknown}")
  end

  # @param [Member] person
  # @return [String]
  def surname_of(person)
    person.name.to_s.split(",").first.to_s.strip
  end

  # @param [Member] person
  # @return [String, nil]
  def given_name_of(person)
    person.name.to_s.split(",", 2).last.to_s.strip.split.first
  end

  # Members are named "Last, First Middle", so the surname is what comes before the comma. A name entered without
  # one falls back to its last word.
  # @return [String, nil]
  def last_name
    return if speaker_name.blank?

    surname, given_names = speaker_name.split(",", 2)

    given_names.present? ? surname.strip : surname.strip.split.last
  end

  # Substituted by hand rather than with `format`, which raises on a literal % -- the wording is meant to be edited
  # freely, and "Give 100% effort" should not be able to break a page.
  # @param [String] segment
  # @return [String, nil] nil when the segment depends on a detail we do not have
  def render(segment)
    keys = segment.scan(INTERPOLATION_PATTERN).flatten.map(&:to_sym)
    return if keys.any? { |key| substitutions[key].blank? }

    segment.gsub(INTERPOLATION_PATTERN) { substitutions[Regexp.last_match(1).to_sym] }
  end

  # @param [Symbol] medium
  # @return [Array<String>]
  def segments(medium)
    key = "speaker_messages.#{template}.#{category}.#{medium}"
    rendered = I18n.t(key).transform_values { |segment| render(segment) }

    rendered.filter_map do |key, text|
      next if text.blank?

      stands_in_for = fallback_for(key)
      next if stands_in_for.present? && rendered[stands_in_for].present?

      text
    end
  end

  # @param [String] number
  # @return [String]
  def normalize_number(number)
    stripped = number.to_s.strip
    digits = stripped.gsub(/\D/, "")

    stripped.start_with?("+") ? "+#{digits}" : digits
  end

  # @return [Hash]
  def substitutions
    @substitutions ||= {
      first_name: first_name,
      full_name: speaker_name,
      addressed_name: addressed_name,
      honorific: honorific,
      last_name: last_name,
      parents_first_names: parents_first_names,
      parents_name: parents_name,
      meeting_date: formatted_meeting_date,
      meeting_end_time: I18n.t("speaker_messages.defaults.meeting_end_time"),
      purpose: purpose,
      sender_honorific: sender.present? ? I18n.t("speaker_messages.defaults.sender_honorific") : nil,
      sender_last_name: sender&.last_name,
      sender_name: sender&.name,
      speaker_pronoun: speaker_pronoun,
      speaking_time: speaking_time,
      topic: topic,
      unit_name: unit&.name,
    }
  end
end
