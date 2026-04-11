class MigrateNotificationsToNoticedV2 < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL.squish
      INSERT INTO noticed_events (type, params, notifications_count, created_at, updated_at)
      SELECT type, params, 1, created_at, updated_at
      FROM notifications
    SQL

    execute <<~SQL.squish
      INSERT INTO noticed_notifications (type, event_id, recipient_type, recipient_id, read_at, created_at, updated_at)
      SELECT n.type || '::Notification', ne.id, n.recipient_type, n.recipient_id, n.read_at, n.created_at, n.updated_at
      FROM notifications n
      INNER JOIN noticed_events ne
        ON ne.type = n.type
        AND ne.created_at = n.created_at
        AND ne.params::text = n.params::text
    SQL

    drop_table :notifications
  end

  def down
    create_table :notifications do |t|
      t.string :recipient_type, null: false
      t.bigint :recipient_id, null: false
      t.string :type, null: false
      t.jsonb :params
      t.datetime :read_at
      t.timestamps
      t.index :read_at
      t.index %i[recipient_type recipient_id], name: "index_notifications_on_recipient"
    end
  end
end
