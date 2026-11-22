# A personal access token a user creates so the CLI or an MCP client can reach Edify's API without their password
# (#315). Only a SHA-256 digest of the token is stored. The plaintext is available from #plaintext_token on the
# instance that created it, for showing to the user once, and can never be recovered afterwards.
#
# A token is usable until it is revoked or reaches its optional expiry. Scopes default to read-only, so a token made
# before write endpoints exist does not gain write access when they ship.
class ApiToken < ApplicationRecord
  PREFIX = "edify_".freeze
  SCOPES = %w[read write].freeze
  LAST_USED_THROTTLE = 5.minutes

  belongs_to :user

  attr_reader :plaintext_token

  before_validation :assign_token, on: :create

  validates :name, presence: true, length: { maximum: 100 }
  validates :token_digest, presence: true, uniqueness: true
  validate :scopes_are_known
  validate :user_is_assigned_to_unit, on: :create
  validate :expires_in_the_future, on: :create

  strip_attributes

  scope :active, -> { where(revoked_at: nil).where("expires_at IS NULL OR expires_at > ?", Time.current) }
  scope :newest_first, -> { order(created_at: :desc) }

  # @param [String, nil] token the plaintext token from an Authorization header
  # @return [ApiToken, nil] the matching token, or nil if it is unknown, revoked or expired
  def self.authenticate(token)
    return if token.blank?

    active.find_by(token_digest: digest(token))
  end

  # @param [String] token
  # @return [String]
  def self.digest(token)
    ::OpenSSL::Digest::SHA256.hexdigest(token)
  end

  def active?
    !revoked? && !expired?
  end

  def expired?
    expires_at.present? && expires_at <= Time.current
  end

  def revoked?
    revoked_at.present?
  end

  def revoke!
    update!(revoked_at: Time.current) unless revoked?
  end

  # @param [String, Symbol] scope
  def scope?(scope)
    scopes.include?(scope.to_s)
  end

  # Records that the token was just used, writing at most once per LAST_USED_THROTTLE so every request is not a
  # write. Skips validations and leaves updated_at alone, since using a token is not editing it.
  def touch_last_used!
    return if last_used_at.present? && last_used_at > LAST_USED_THROTTLE.ago

    update_column(:last_used_at, Time.current)
  end

  private

  attr_writer :plaintext_token

  def assign_token
    return if token_digest.present?

    self.plaintext_token = "#{PREFIX}#{::SecureRandom.base58(32)}"
    self.token_digest = self.class.digest(plaintext_token)
  end

  def expires_in_the_future
    return if expires_at.nil? || expires_at > Time.current

    errors.add(:expires_at, "must be in the future")
  end

  def scopes_are_known
    if scopes.blank?
      errors.add(:scopes, "must include at least one scope")
    elsif (unknown = scopes - SCOPES).any?
      errors.add(:scopes, "include unknown scopes: #{unknown.join(', ')}")
    end
  end

  def user_is_assigned_to_unit
    return if user.nil? || user.assigned_to_unit?

    errors.add(:user, "must be assigned to a unit to create an API token")
  end
end
