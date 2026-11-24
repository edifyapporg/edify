class User < ApplicationRecord
  devise :database_authenticatable,
         :confirmable,
         :registerable,
         :recoverable,
         :rememberable,
         :validatable

  has_one_attached :avatar
  has_person_name
  has_noticed_notifications param_name: :user

  enum :role, {
    bishopric: 1,
    clerk: 2,
    music: 3,
    program: 4,
  }

  has_many :api_tokens, dependent: :destroy
  has_many :import_jobs, foreign_key: :owner_id, dependent: :nullify
  has_many :scheduled_meetings, class_name: "Meeting", foreign_key: :scheduler_id, dependent: :nullify
  has_many :notifications, as: :recipient, dependent: :destroy, class_name: "Noticed::Notification"
  has_one :access_request, dependent: :destroy
  belongs_to :unit, optional: true

  before_validation :set_notification_preferences
  after_update :revoke_oauth_access, if: :saved_change_to_encrypted_password?
  after_commit :send_welcome_notifications

  # True after a password change, made through this instance, that disconnected apps the user had connected (#390).
  attr_reader :oauth_access_revoked
  alias oauth_access_revoked? oauth_access_revoked

  scope :admin, -> { where(admin: true) }
  scope :alphabetical, -> { order(:first_name) }
  scope :approvers, -> { where(role: :bishopric) }
  scope :meeting_schedulers, -> { where(role: [:bishopric]) }

  validates :first_name, presence: true
  validates :phone_number, phone: { allow_blank: true }

  strip_attributes

  def access_to_lcr?
    assigned_to_unit? && (bishopric? || clerk?)
  end

  def assigned_to_unit?
    unit_id?
  end

  def bishopric?
    role == "bishopric"
  end

  def clerk?
    role == "clerk"
  end

  def music?
    role == "music"
  end

  def music_editor?
    assigned_to_unit? &&
      (bishopric? || music?)
  end

  def needs_onboarding?
    unit_id.nil? && access_request.nil?
  end

  def pending_unit
    access_request&.unit
  end

  def unit_admin?
    assigned_to_unit? && bishopric?
  end

  def unit_name
    unit&.name
  end

  private

  # A password change, whether in settings or through a reset email, ends every OAuth connection, so a client someone
  # connected while they controlled the account stops working (#390). Personal API tokens are left alone: revoking
  # them would break the leader's own scripts and CLI, so the flash notice lists them instead.
  def revoke_oauth_access
    @oauth_access_revoked = ::OauthApplication.connected_for(self).exists?
    now = Time.current
    ::OauthAccessToken.where(resource_owner_id: id, revoked_at: nil).update_all(revoked_at: now)
    ::Doorkeeper.config.access_grant_model.where(resource_owner_id: id, revoked_at: nil).update_all(revoked_at: now)
  end

  def send_welcome_notifications
    return true unless newly_confirmed?

    ::NewUserAdminNotification.with(user: self).deliver(::User.admin)
    ::NewUserNotification.with(user: self).deliver(self)
  end

  def set_notification_preferences
    self.notification_preference_email = true if notification_preference_email.nil?
  end

  def newly_confirmed?
    saved_changes["confirmed_at"].present? && saved_changes["confirmed_at"].first.nil?
  end
end
