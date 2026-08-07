class CreateDuplicateDismissals < ActiveRecord::Migration[8.1]
  def change
    create_table :duplicate_dismissals do |t|
      t.references :unit, null: false, foreign_key: true
      t.references :member_a, null: false, foreign_key: { to_table: :members, on_delete: :cascade }
      t.references :member_b, null: false, foreign_key: { to_table: :members, on_delete: :cascade }
      t.integer :dismissed_by

      t.timestamps
    end

    add_index :duplicate_dismissals, [:member_a_id, :member_b_id], unique: true
  end
end
