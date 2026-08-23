class RemoveNotificationPreferenceSmsFromUsers < ActiveRecord::Migration[8.1]
  def change
    remove_column :users, :notification_preference_sms, :boolean
  end
end
