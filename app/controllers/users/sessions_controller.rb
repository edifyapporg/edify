module Users
  # Devise's sign-in, rate-limited (#391).
  class SessionsController < Devise::SessionsController
    include AuthRateLimiting

    limit_auth_attempts :create, per_ip: 20, per_email: 10, within: 10.minutes
  end
end
