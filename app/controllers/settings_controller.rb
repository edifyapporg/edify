class SettingsController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_action
  after_action :verify_authorized

  # GET /settings/preferences
  def preferences
  end

  # GET /settings/avatar
  def avatar
  end

  # GET /settings/password
  def password
  end

  # PUT /settings/update
  def update
    message = current_user.update(settings_update_params) ? nil : current_user.errors.full_messages.join("; ")

    redirect_to request.referrer, notice: message
  end

  # DELETE /settings/remove_avatar
  def remove_avatar
    current_user.avatar.purge if current_user.avatar.attached?

    redirect_to settings_avatar_path
  end

  private

  def authorize_action
    authorize self, policy_class: ::SettingsPolicy
  end

  def settings_update_params
    params
      .expect(
        user: [:avatar,
               :email,
               :hide_moved_members,
               :name,
               :notification_preference_email,
               :phone_number]
      )
  end
end
