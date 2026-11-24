class EdifyConfig
  def self.app_url
    ::ENV["APP_URL"] || "localhost:3000" # rubocop:disable Rails/EnvironmentVariableAccess
  end

  def self.cloudflare_turnstile_secret_key
    Rails.application.credentials.dig(:cloudflare, :turnstile, :secret_key)
  end

  def self.cloudflare_turnstile_site_key
    Rails.application.credentials.dig(:cloudflare, :turnstile, :site_key)
  end

  def self.cloudflare_turnstile_site_verify_url
    "https://challenges.cloudflare.com/turnstile/v0/siteverify"
  end

  def self.cloudflare_turnstile_js_url
    "https://challenges.cloudflare.com/turnstile/v0/api.js"
  end

  # The Handbook's main page, not a section: section numbers and anchors change without notice (#369).
  def self.general_handbook_url
    "https://www.churchofjesuschrist.org/study/manual/general-handbook"
  end

  def self.email_sender_address
    "no-reply@#{app_url}"
  end

  # Where a user writes for help when they can't reach their own account, e.g. after someone else changed its email
  # address (#397). Unset in development; the emails that mention it fall back to the bishopric.
  def self.support_email_address
    ::ENV["SUPPORT_EMAIL_ADDRESS"].presence # rubocop:disable Rails/EnvironmentVariableAccess
  end

  # The MCP endpoint is open to site admins only until this is set, pending the privacy review in #315.
  def self.mcp_enabled_for_everyone?
    ::ENV["MCP_ENABLED"] == "true" # rubocop:disable Rails/EnvironmentVariableAccess
  end

  def self.mailgun_api_key
    Rails.application.credentials.dig(:mailgun, :api_key)
  end

  def self.mailgun_domain
    Rails.application.credentials.dig(:mailgun, :domain)
  end

  def self.mailgun_webhook_signing_key
    Rails.application.credentials.dig(:mailgun, :webhook_signing_key)
  end

  def self.scout_apm_key
    Rails.application.credentials.dig(:scout, :agent_key)
  end

  def self.scout_apm_logs_ingest_key
    Rails.application.credentials.dig(:scout, :logs_ingest_key) || "test_key"
  end
end
