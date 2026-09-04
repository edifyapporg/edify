class CreateHouseholds < ActiveRecord::Migration[8.1]
  def change
    create_table :households do |t|
      t.references :unit, null: false, foreign_key: true
      t.string :name, null: false
      t.string :address_lines, array: true, null: false, default: []
      t.string :phone_number
      t.string :email
      t.date :synced_on

      t.timestamps
    end

    add_index :households, [:unit_id, :name], unique: true
  end
end
