class AddBaptizedToMembers < ActiveRecord::Migration[8.1]
  # Nullable with no default: the directory reports baptism status, so a member Edify has not seen in an import since
  # this column arrived is genuinely unknown rather than assumed either way.
  def change
    add_column :members, :baptized, :boolean
  end
end
