module SpeakerMessagesHelper
  # Every place a message can be sent from, in the order the links are listed.
  MEDIA = %i[sms email].freeze

  # @param [Member] member
  # @option options [Symbol, Array<Symbol>] :media the media to offer links for; defaults to all of them
  # @return [String, nil] nil when the member cannot be reached by any of the requested media
  def speaker_message_dropdown_for_member(member, options = {})
    messages = SpeakerMessage::TEMPLATES.map do |template|
      SpeakerMessage.for_member(member, template: template, sender: current_user, unit: current_unit)
    end

    speaker_message_dropdown(messages, options)
  end

  # @param [Talk] talk
  # @option options [Symbol, Array<Symbol>] :media the media to offer links for; defaults to all of them
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
    media = Array(options.delete(:media).presence || MEDIA)
    items = speaker_message_dropdown_items(messages, media)

    return if items.empty?

    text = options.key?(:text) ? options.delete(:text) : " Message"
    title = text.present? ? fa_icon("paper-plane", text: text) : fa_icon("paper-plane")

    build_dropdown_menu(title, items, options)
  end

  # @param [Array<SpeakerMessage>] messages
  # @param [Array<Symbol>] media
  # @return [Array<Hash>]
  def speaker_message_dropdown_items(messages, media = MEDIA)
    text_items = speaker_message_links(messages, :sms) if media.include?(:sms)
    email_items = speaker_message_links(messages, :email) if media.include?(:email)
    text_items ||= []
    email_items ||= []

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
end
