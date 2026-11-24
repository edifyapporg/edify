# Rate limits for Devise's sign-in, password-reset and confirmation forms (#391), against password guessing,
# credential stuffing, and floods of reset emails. Each form is limited both per client IP and per submitted email
# address, so neither many guesses from one address nor guesses spread across many addresses at one account get far.
# Counts live in Rails.cache. A request over either limit is sent back to the form with a flash alert, before Devise
# or Warden sees it.
module AuthRateLimiting
  extend ActiveSupport::Concern

  class_methods do
    # @param action [Symbol] the action to limit
    # @param per_ip [Integer] requests allowed from one IP within the window
    # @param per_email [Integer] requests allowed for one email address within the window
    # @param within [ActiveSupport::Duration] the window
    def limit_auth_attempts(action, per_ip:, per_email:, within:)
      rate_limit to: per_ip, within: within, name: "ip", by: -> { request.remote_ip }, with: :auth_rate_limited,
                 store: ::Rails.cache, only: action, prepend: true
      rate_limit to: per_email, within: within, name: "email", by: :submitted_email_key, with: :auth_rate_limited,
                 store: ::Rails.cache, only: action, prepend: true
    end
  end

  private

  # Hashed, so cache keys never hold an email address.
  def submitted_email_key
    ::Digest::SHA256.hexdigest(params.dig(:user, :email).to_s.strip.downcase)
  end

  def auth_rate_limited
    redirect_to({ action: :new }, alert: I18n.t("controllers.auth_rate_limiting.too_many_attempts"), status: :see_other)
  end
end
