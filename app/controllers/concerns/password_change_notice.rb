# Adds to the flash notice after a password change what it did to the user's other access (#390): apps they had
# connected were disconnected (User#revoke_oauth_access), and personal API tokens still work. The tokens are listed
# by name and creation date, so one created by someone else while they controlled the account stands out.
module PasswordChangeNotice
  extend ActiveSupport::Concern

  # The flash lives in the session cookie, so a user with many tokens gets the newest few and a count of the rest.
  LISTED_API_TOKENS = 5

  private

  # @param user [User] the user whose password was just changed
  def append_password_change_notice(user)
    notes = []
    notes << I18n.t("controllers.password_change_notice.apps_disconnected") if user.oauth_access_revoked?
    notes << active_api_tokens_note(user)
    notes.compact!
    flash[:notice] = [flash[:notice], *notes].compact.join(" ") if notes.any?
  end

  # @param user [User]
  # @return [String, nil] the user's active API tokens, newest first, or nil if there are none
  def active_api_tokens_note(user)
    tokens = user.api_tokens.active.order(created_at: :desc)
    count = tokens.count
    return if count.zero?

    listed = tokens.limit(LISTED_API_TOKENS).map do |token|
      I18n.t("controllers.password_change_notice.api_token",
             name: token.name, date: I18n.l(token.created_at.to_date, format: :rfc822))
    end
    if count > listed.size
      listed << I18n.t("controllers.password_change_notice.more_api_tokens",
                       count: count - listed.size)
    end
    I18n.t("controllers.password_change_notice.api_tokens_active", count: count, tokens: listed.to_sentence)
  end
end
