module SpeakerMessagesHelper
  # @param [Member] member
  # @return [String, nil] nil when the member has no phone number or email
  def speaker_message_dropdown_for_member(member, options = {})
    messages = SpeakerMessage::TEMPLATES.map do |template|
      SpeakerMessage.for_member(member, template: template, sender: current_user, unit: current_unit)
    end

    speaker_message_dropdown(messages, options)
  end

  # @param [Talk] talk
  # @return [String, nil] nil when the speaker is not matched to a member with a phone number or email
  def speaker_message_dropdown_for_talk(talk, options = {})
    messages = SpeakerMessage::TEMPLATES.map do |template|
      SpeakerMessage.for_talk(talk, template: template, sender: current_user, unit: current_unit)
    end

    speaker_message_dropdown(messages, options)
  end

  # @param [Array<SpeakerMessage>] messages
  # @return [String, nil]
  def speaker_message_dropdown(messages, options = {})
    return if messages.none?(&:available?)

    text = options.key?(:text) ? options.delete(:text) : " Message"
    title = text.present? ? fa_icon("paper-plane", text: text) : fa_icon("paper-plane")

    build_dropdown_menu(title, speaker_message_dropdown_items(messages), options)
  end

  # @param [Array<SpeakerMessage>] messages
  # @return [Array<Hash>]
  def speaker_message_dropdown_items(messages)
    text_items = messages.select(&:sms_available?).map do |message|
      { name: "Text: #{message.label}", link: message.sms_url, data: { turbo: false } }
    end

    email_items = messages.select(&:email_available?).map do |message|
      { name: "Email: #{message.label}", link: message.mailto_url, data: { turbo: false } }
    end

    return text_items + email_items if text_items.empty? || email_items.empty?

    text_items + [{ role: :separator }] + email_items
  end
end
