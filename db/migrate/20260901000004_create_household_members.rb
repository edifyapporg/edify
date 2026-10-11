class CreateHouseholdMembers < ActiveRecord::Migration[8.1]
  # One row per name listed under a household. `member_id` is nullable on purpose: the household directory carries no
  # gender or birthdate, so it can never create a Member, and an entry may name someone the individual directory has
  # not been imported for yet. Those rows still hold everything the directory said, and link up on a later import.
  def change
    create_table :household_members do |t|
      t.references :household, null: false, foreign_key: true
      t.references :member, foreign_key: true
      t.string :name, null: false
      t.integer :listed_age
      t.integer :position, null: false
      t.boolean :parent, null: false, default: false

      t.timestamps
    end

    add_index :household_members, [:household_id, :position], unique: true
  end
end
