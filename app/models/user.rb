class User < ApplicationRecord
  devise :database_authenticatable,
         :confirmable,
         :registerable,
         :recoverable,
         :rememberable,
         :validatable,
         :jwt_authenticatable, jwt_revocation_strategy: Devise::JWT::RevocationStrategies::Null

  has_one_attached :avatar
  has_person_name
  has_noticed_notifications param_name: :user

  enum :role, {
    bishopric: 1,
    clerk: 2,
    music: 3,
    program: 4,
  }

  has_many :import_jobs, foreign_key: :owner_id, dependent: :nullify
  has_many :scheduled_meetings, class_name: "Meeting", foreign_key: :scheduler_id, dependent: :nullify
  has_many :notifications, as: :recipient, dependent: :destroy, class_name: "Noticed::Notification"
  has_one :access_request, dependent: :destroy
  belongs_to :unit, optional: true

  before_validation :set_notification_preferences
  after_commit :send_welcome_notifications

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

  def send_welcome_notifications
    return true unless newly_confirmed?

    ::NewUserAdminNotification.with(user: self).deliver(::User.admin)
    ::NewUserNotification.with(user: self).deliver(self)
  end

  def set_notification_preferences
    self.notification_preference_email = true if notification_preference_email.nil?
    self.notification_preference_sms = phone_number.present? if notification_preference_sms.nil?
    self.notification_preference_sms = false if phone_number.blank?
  end

  def newly_confirmed?
    saved_changes["confirmed_at"].present? && saved_changes["confirmed_at"].first.nil?
  end
end
