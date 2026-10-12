class AddHideMovedMembersToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :hide_moved_members, :boolean, default: true, null: false
  end
end
