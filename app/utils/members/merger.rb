module Members
  # Merges two member records that represent the same person. The +keep+ record
  # is preserved; the +remove+ record's talks, notes and household entries are
  # reassigned to it and any contact/pause details missing on +keep+ are
  # backfilled, then +remove+ is deleted. Runs in a transaction so a failure
  # leaves both records untouched.
  class Merger
    CONTACT_ATTRIBUTES = %i[email phone_number].freeze

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
      # Talks and household entries nullify and notes are destroyed when a member is
      # deleted, so all three must be reassigned to the surviving record before
      # removing the stale one.
      Talk.where(member_id: remove.id).update_all(member_id: keep.id)
      Note.where(member_id: remove.id).update_all(member_id: keep.id)
      HouseholdMember.where(member_id: remove.id).update_all(member_id: keep.id)
    end

    def backfill_missing_details
      CONTACT_ATTRIBUTES.each do |attribute|
        keep[attribute] = remove[attribute] if keep[attribute].blank? && remove[attribute].present?
      end

      # Pause fields move as a unit; the paused? gate lets remove's active pause
      # overwrite a stale/expired one on keep.
      if !keep.paused? && remove.paused?
        keep.paused_until = remove.paused_until
        keep.paused_on = remove.paused_on
        keep.paused_by = remove.paused_by
      end

      keep.save!
    end
  end
end
