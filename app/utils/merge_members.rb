# Merges two member records that represent the same person. The +keep+ record
# is preserved; the +remove+ record's talks and notes are reassigned to it and
# any contact/pause details missing on +keep+ are backfilled, then +remove+ is
# deleted. Runs in a transaction so a failure leaves both records untouched.
class MergeMembers
  # @param keep [Member] the surviving record
  # @param remove [Member] the record to delete
  # @return [Member] the surviving record
  def self.call(keep:, remove:)
    new(keep: keep, remove: remove).call
  end

  def initialize(keep:, remove:)
    @keep = keep
    @remove = remove
  end

  # @return [Member]
  def call
    raise ArgumentError, "cannot merge a member into itself" if keep.id == remove.id

    ActiveRecord::Base.transaction do
      reassign_associations
      backfill_missing_details
      remove.destroy!
    end

    keep
  end

  private

  attr_reader :keep, :remove

  def reassign_associations
    # Talks nullify and notes are destroyed when a member is deleted, so both
    # must be reassigned to the surviving record before removing the stale one.
    Talk.where(member_id: remove.id).update_all(member_id: keep.id)
    Note.where(member_id: remove.id).update_all(member_id: keep.id)
  end

  def backfill_missing_details
    attributes = {}
    attributes[:email] = remove.email if keep.email.blank? && remove.email.present?
    attributes[:phone_number] = remove.phone_number if keep.phone_number.blank? && remove.phone_number.present?

    if !keep.paused? && remove.paused?
      attributes[:paused_until] = remove.paused_until
      attributes[:paused_on] = remove.paused_on
      attributes[:paused_by] = remove.paused_by
    end

    keep.update!(attributes) if attributes.any?
  end
end
