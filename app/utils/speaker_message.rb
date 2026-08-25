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
  YOUTH_MAX_AGE = 17

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
    member.present? && member.email.present?
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

    "mailto:#{member.email}?subject=#{encode(subject)}&body=#{encode(email_body)}"
  end

  # @return [Boolean]
  def sms_available?
    member.present? && member.phone_number.present?
  end

  # @return [String]
  def sms_body
    body(:sms)
  end

  # @return [String, nil]
  def sms_url
    return unless sms_available?

    # `?&body=` is the one separator both iOS and Android accept for a pre-filled message.
    "sms:#{sms_number}?&body=#{encode(sms_body)}"
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

  # Youth are asked to speak for less time than adults. Without a member on record, or without their birthdate, we
  # cannot tell, so we assume an adult -- the longer talk is the safer thing to over-prepare for.
  # @return [String]
  def duration
    youth = member&.birthdate.present? && member.age <= YOUTH_MAX_AGE

    I18n.t("speaker_messages.defaults.duration.#{youth ? :youth : :adult}")
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
    return if member&.gender.blank?

    I18n.t("speaker_messages.defaults.honorific.#{member.gender}")
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
    rendered = I18n.t("speaker_messages.#{template}.#{medium}").transform_values { |segment| render(segment) }

    rendered.filter_map do |key, text|
      next if text.blank?

      stands_in_for = fallback_for(key)
      next if stands_in_for.present? && rendered[stands_in_for].present?

      text
    end
  end

  # @return [String]
  def sms_number
    number = member.phone_number.to_s.strip
    digits = number.gsub(/\D/, "")

    number.start_with?("+") ? "+#{digits}" : digits
  end

  # @return [Hash]
  def substitutions
    @substitutions ||= {
      duration: duration,
      first_name: first_name,
      full_name: speaker_name,
      honorific: honorific,
      last_name: last_name,
      meeting_date: formatted_meeting_date,
      meeting_end_time: I18n.t("speaker_messages.defaults.meeting_end_time"),
      purpose: purpose,
      sender_honorific: sender.present? ? I18n.t("speaker_messages.defaults.sender_honorific") : nil,
      sender_last_name: sender&.last_name,
      sender_name: sender&.name,
      topic: topic,
      unit_name: unit&.name,
    }
  end
end
