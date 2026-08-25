module Members
  # Applies the "members_" table-name prefix to models in this namespace, so
  # Members::DuplicateDismissal maps to the members_duplicate_dismissals table
  # (see the rename in the migration prepared for this feature).
  def self.table_name_prefix
    "members_"
  end
end
