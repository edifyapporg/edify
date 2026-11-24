# Deletes OAuth rows that can no longer do anything (#389). Runs daily from config/recurring.yml.
#
# - Access tokens older than OauthAccessToken::REFRESH_TOKEN_LIFETIME, revoked or not. Their access token expired
#   long ago and their refresh token no longer works. Revoked tokens younger than that are kept: they are inert, and
#   keeping them leaves Settings > Connected Apps exactly as it was: for a connected app, OauthApplication.connected_for
#   and #last_authorized_at depend only on tokens younger than the lifetime.
# - Authorization grants older than GRANT_RETENTION. A code is used at once or expires in minutes, so every one that
#   old is used, revoked or expired.
class OauthSweepJob < ::ApplicationJob
  GRANT_RETENTION = 1.day

  queue_as :default

  def perform(*_args)
    ::OauthAccessToken.where(created_at: ...::OauthAccessToken::REFRESH_TOKEN_LIFETIME.ago).in_batches(&:delete_all)
    ::Doorkeeper.config.access_grant_model.where(created_at: ...GRANT_RETENTION.ago).in_batches(&:delete_all)
  end
end
