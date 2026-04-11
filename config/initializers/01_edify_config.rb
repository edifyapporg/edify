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

  def self.email_sender_address
    "no-reply@#{app_url}"
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
