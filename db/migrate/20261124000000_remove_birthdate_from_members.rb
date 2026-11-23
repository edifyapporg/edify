class RemoveBirthdateFromMembers < ActiveRecord::Migration[8.1]
  # The last of three steps that replace members' full birthdates with birth years (#370). The deployed code already
  # ignores `birthdate` and reads `birth_year`. This step fills `birth_year` for any member it is still missing,
  # replaces the global (name, birthdate) unique index with a per-unit (unit_id, name, birth_year) one, and drops
  # `birthdate`.
  #
  # Rolling back restores the column and the old index, but not the dates: they are deleted here on purpose.
  def up
    execute <<~SQL.squish
      UPDATE members SET birth_year = EXTRACT(YEAR FROM birthdate)::integer
      WHERE birth_year IS NULL AND birthdate IS NOT NULL
    SQL

    remove_index :members, [:name, :birthdate], name: "index_members_on_name_and_birthdate", unique: true
    add_index :members, [:unit_id, :name, :birth_year], unique: true
    remove_column :members, :birthdate, :date
  end

  def down
    add_column :members, :birthdate, :date
    remove_index :members, [:unit_id, :name, :birth_year], unique: true
    add_index :members, [:name, :birthdate], name: "index_members_on_name_and_birthdate", unique: true
  end
end
