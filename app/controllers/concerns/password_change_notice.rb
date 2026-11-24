# Adds to the flash notice after a password change what it did to the user's other access (#390): apps they had
# connected were disconnected (User#revoke_oauth_access), and personal API tokens still work.
module PasswordChangeNotice
  extend ActiveSupport::Concern

  private

  # @param user [User] the user whose password was just changed
  def append_password_change_notice(user)
    notes = []
    notes << I18n.t("controllers.password_change_notice.apps_disconnected") if user.oauth_access_revoked?
    api_token_count = user.api_tokens.active.count
    if api_token_count.positive?
      notes << I18n.t("controllers.password_change_notice.api_tokens_active",
                      count: api_token_count)
    end
    flash[:notice] = [flash[:notice], *notes].compact.join(" ") if notes.any?
  end
end
