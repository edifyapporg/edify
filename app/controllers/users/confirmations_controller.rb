module Users
  # Devise's resend-confirmation form, rate-limited (#391) so it can't be used to flood an inbox.
  class ConfirmationsController < Devise::ConfirmationsController
    include AuthRateLimiting

    limit_auth_attempts :create, per_ip: 10, per_email: 3, within: 15.minutes
  end
end
