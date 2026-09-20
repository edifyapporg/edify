module SpeakerMessagesHelper
  # How many Sundays out a member can be invited to speak.
  INVITATION_SUNDAYS = 6

  # A Sunday picker and a text-message link side by side in a box of their own, so it reads as one action: inviting
  # the member to speak on the Sunday shown. Every Sunday's message is built up front and carried on its option, and
  # the Stimulus controller swaps the link as the picker changes.
  # @param [Member] member
  # @return [String, nil] nil when the member has no phone number to text
  def speaker_invitation_box(member, options = {})
    invitations = speaker_invitations(member)

    return unless invitations.first&.last&.sms_available?

    content_tag(:div, class: ["d-inline-flex align-items-center gap-2 border rounded p-2", options[:class]].compact,
                      data: { controller: "speaker-invitation" }) do
      concat speaker_invitation_dates(invitations)
      concat speaker_invitation_link(invitations.first.last)
    end
  end

  # @param [Talk] talk
  # @return [String, nil] nil when the speaker is not matched to a member with an email address
  def speaker_reminder_link(talk, options = {})
    message = SpeakerMessage.for_talk(talk, template: :reminder, sender: current_user, unit: current_unit)

    return unless message.email_available?

    link_to fa_icon("paper-plane"), message.mailto_url,
            class: ["btn btn-sm btn-outline-secondary", options[:class]].compact,
            title: "Email #{message.spoken_name} a reminder",
            data: { turbo: false, "bs-toggle" => "tooltip" }
  end

  # @param [Talk] talk
  # @return [String, nil] nil when the speaker is not matched to a member who can be reached
  def speaker_message_dropdown_for_talk(talk, options = {})
    messages = SpeakerMessage::TEMPLATES.map do |template|
      SpeakerMessage.for_talk(talk, template: template, sender: current_user, unit: current_unit)
    end

    speaker_message_dropdown(messages, options)
  end

  # @param [Array<SpeakerMessage>] messages
  # @return [String, nil]
  def speaker_message_dropdown(messages, options = {})
    items = speaker_message_dropdown_items(messages)

    return if items.empty?

    text = options.key?(:text) ? options.delete(:text) : " Message"
    title = text.present? ? fa_icon("paper-plane", text: text) : fa_icon("paper-plane")

    build_dropdown_menu(title, items, options)
  end

  # @param [Array<SpeakerMessage>] messages
  # @return [Array<Hash>]
  def speaker_message_dropdown_items(messages)
    text_items = speaker_message_links(messages, :sms)
    email_items = speaker_message_links(messages, :email)

    return text_items + email_items if text_items.empty? || email_items.empty?

    text_items + [{ role: :separator }] + email_items
  end

  # @param [Array<SpeakerMessage>] messages
  # @param [Symbol] medium
  # @return [Array<Hash>]
  def speaker_message_links(messages, medium)
    prefix, availability, url = if medium == :sms
                                  ["Text", :sms_available?, :sms_url]
                                else
                                  ["Email", :email_available?, :mailto_url]
                                end

    messages.select(&availability).map do |message|
      { name: "#{prefix}: #{message.label}", link: message.public_send(url), data: { turbo: false } }
    end
  end

  # The Sundays a member can be invited to speak on, starting with the next one.
  # @return [Array<Date>]
  def invitation_sundays
    first = Date.current.next_occurring(:sunday)

    Array.new(INVITATION_SUNDAYS) { |weeks| first + weeks.weeks }
  end

  private

  # @param [Member] member
  # @return [Array<Array(Date, SpeakerMessage)>]
  def speaker_invitations(member)
    invitation_sundays.map do |date|
      [date, SpeakerMessage.for_member(member, template: :invitation, meeting_date: date, sender: current_user,
                                               unit: current_unit)]
    end
  end

  # @param [Array<Array(Date, SpeakerMessage)>] invitations
  # @return [String]
  def speaker_invitation_dates(invitations)
    choices = invitations.map do |date, message|
      content_tag(:option, l(date, format: :month_and_day), value: date.to_fs(:iso8601),
                                                            data: { href: message.sms_url })
    end

    content_tag(:select, safe_join(choices), class: "form-select form-select-sm w-auto",
                                             aria: { label: "Sunday to invite this member to speak on" },
                                             data: { speaker_invitation_target: "date",
                                                     action: "change->speaker-invitation#pick" })
  end

  # @param [SpeakerMessage] message the invitation for the Sunday the picker starts on
  # @return [String]
  def speaker_invitation_link(message)
    link_to fa_icon("paper-plane", text: " Text invitation"), message.sms_url,
            class: "btn btn-sm btn-outline-secondary text-nowrap",
            data: { turbo: false, speaker_invitation_target: "link" }
  end
end
