# The state between the two steps of signing in with an authenticator app: the password was right, and Edify is
# waiting for a code. It lives in the session cookie, which Rails encrypts, and expires after a few minutes. The
# password salt is kept with it, so changing the password in the meantime makes it invalid.
module PendingTwoFactorSignIn
  extend ActiveSupport::Concern

  PENDING_SIGN_IN_KEY = :pending_two_factor_sign_in
  PENDING_SIGN_IN_LIFETIME = 5.minutes

  private

  def start_two_factor_sign_in(user, remember_me:)
    session[PENDING_SIGN_IN_KEY] = {
      "user_id" => user.id,
      "salt" => user.authenticatable_salt,
      "remember_me" => remember_me,
      "expires_at" => PENDING_SIGN_IN_LIFETIME.from_now.to_i,
    }
  end

  # @return [User, nil] the user who entered a password and still owes a code, or nil if none or it expired
  def pending_two_factor_user
    pending = session[PENDING_SIGN_IN_KEY]
    return if pending.blank? || pending["expires_at"].to_i < ::Time.current.to_i

    user = ::User.find_by(id: pending["user_id"])
    user if user&.otp_required_for_login && user.authenticatable_salt == pending["salt"]
  end

  def pending_two_factor_remember_me?
    session.dig(PENDING_SIGN_IN_KEY, "remember_me") == true
  end

  def pending_two_factor_user_id
    session.dig(PENDING_SIGN_IN_KEY, "user_id").to_s
  end

  def clear_pending_two_factor_sign_in
    session.delete(PENDING_SIGN_IN_KEY)
  end
end
