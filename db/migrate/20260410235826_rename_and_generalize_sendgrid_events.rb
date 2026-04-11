class RenameAndGeneralizeSendgridEvents < ActiveRecord::Migration[8.0]
  def change
    rename_table :sendgrid_events, :email_events

    rename_column :email_events, :sg_event_id, :provider_event_id
    rename_column :email_events, :sg_message_id, :provider_message_id

    add_column :email_events, :type, :string

    reversible do |dir|
      dir.up do
        execute "UPDATE email_events SET type = 'SendgridEvent'"
      end
    end
  end
end
