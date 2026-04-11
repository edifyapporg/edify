class RenameAndGeneralizeSendgridEvents < ActiveRecord::Migration[8.0]
  def change
    rename_table :sendgrid_events, :analytics_email_events

    rename_column :analytics_email_events, :sg_event_id, :provider_event_id
    rename_column :analytics_email_events, :sg_message_id, :provider_message_id

    add_column :analytics_email_events, :type, :string

    reversible do |dir|
      dir.up do
        execute "UPDATE analytics_email_events SET type = 'Analytics::SendgridEvent'"
      end
    end
  end
end
