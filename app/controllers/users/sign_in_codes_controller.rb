module Users
  # The second step of signing in, for a user with an authenticator app turned on: a code from the app, or one of the
  # user's recovery codes. Each recovery code works once. Attempts are rate-limited per IP and per account, like the
  # password step.
  class SignInCodesController < ApplicationController
    include AuthRateLimiting
    include PendingTwoFactorSignIn

    rate_limit to: 20, within: 10.minutes, name: "ip", by: -> { request.remote_ip }, with: :auth_rate_limited,
               store: ::Rails.cache, only: :create
    rate_limit to: 10, within: 10.minutes, name: "account", by: -> { pending_two_factor_user_id },
               with: :auth_rate_limited, store: ::Rails.cache, only: :create

    before_action :redirect_signed_in_user
    before_action :set_user

    def new
    end

    def create
      code = params[:code].to_s.strip

      if @user.validate_and_consume_otp!(code)
        finish_sign_in(notice: t("devise.sessions.signed_in"))
      elsif @user.invalidate_otp_backup_code!(code.delete(" -").downcase)
        finish_sign_in(notice: t("controllers.sign_in_codes.recovery_code_used", count: @user.otp_backup_codes.size))
      else
        flash.now[:alert] = t("controllers.sign_in_codes.invalid_code")
        render :new, status: :unprocessable_content
      end
    end

    private

    def finish_sign_in(notice:)
      remember_me = pending_two_factor_remember_me?
      clear_pending_two_factor_sign_in
      @user.after_database_authentication
      @user.remember_me = remember_me
      sign_in(:user, @user)
      redirect_to after_sign_in_path_for(@user), notice: notice, status: :see_other
    end

    def redirect_signed_in_user
      redirect_to root_path if user_signed_in?
    end

    def set_user
      @user = pending_two_factor_user
      return if @user

      clear_pending_two_factor_sign_in
      redirect_to new_user_session_path, alert: t("controllers.sign_in_codes.expired")
    end
  end
end
