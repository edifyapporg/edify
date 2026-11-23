class AddBirthYearToMembers < ActiveRecord::Migration[8.1]
  # The first of three steps that replace members' full birthdates with birth years (#370). This step only adds the
  # nullable column and fills it from `birthdate`; nothing reads it yet, so it is safe with the deployed code. The
  # code switch and the removal of `birthdate` follow in later PRs. Plain SQL keeps the backfill independent of the
  # Member model, which will change. Rolling back removes the column; `birthdate` is untouched either way.
  def up
    add_column :members, :birth_year, :integer

    execute <<~SQL.squish
      UPDATE members SET birth_year = EXTRACT(YEAR FROM birthdate)::integer WHERE birthdate IS NOT NULL
    SQL
  end

  def down
    remove_column :members, :birth_year, :integer
  end
end
