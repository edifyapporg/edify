class RenameDuplicateDismissalsToMembersDuplicateDismissals < ActiveRecord::Migration[8.1]
  def change
    rename_table :duplicate_dismissals, :members_duplicate_dismissals

    # rename_table hashes the composite index name because the conventional
    # name would exceed Postgres's 63-character identifier limit; give it a
    # readable name instead.
    rename_index :members_duplicate_dismissals,
                 "idx_on_member_a_id_member_b_id_0613c2f0e8",
                 "index_members_duplicate_dismissals_on_member_pair"
  end
end
