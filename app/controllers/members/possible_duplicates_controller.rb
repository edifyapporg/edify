module Members
  class PossibleDuplicatesController < ::ApplicationController
    before_action :authenticate_user!
    after_action :verify_authorized

    # GET /members/possible_duplicates
    def index
      authorize [:members, :possible_duplicate], :index?
      @pairs = DuplicateFinder.call(current_unit)
    end

    # GET /members/possible_duplicates/summary
    # Lazily loaded into a Turbo frame on the Members index.
    def summary
      authorize [:members, :possible_duplicate], :summary?
      @pairs = DuplicateFinder.call(current_unit)
    end

    # PUT /members/possible_duplicates/merge
    def merge
      authorize [:members, :possible_duplicate], :merge?
      keep = current_unit.members.find(params.expect(:keep_id))
      remove = current_unit.members.find(params.expect(:remove_id))

      Merger.call(keep: keep, remove: remove)
      remove_pair_response(keep, remove, notice: "Merged #{remove.name} into #{keep.name}.")
    end

    # POST /members/possible_duplicates/dismiss
    def dismiss
      authorize [:members, :possible_duplicate], :dismiss?
      member_a = current_unit.members.find(params.expect(:member_a_id))
      member_b = current_unit.members.find(params.expect(:member_b_id))

      dismissal = DuplicateDismissal.for(member_a, member_b)
      dismissal.unit = current_unit
      dismissal.dismissed_by = current_user.id
      dismissal.save!

      remove_pair_response(member_a, member_b, notice: "Dismissed possible duplicate.")
    end

    private

    def remove_pair_response(first, second, notice:)
      pair = DuplicatePair.new(first, second)

      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.remove(pair) }
        format.html { redirect_to members_possible_duplicates_path, notice: notice }
      end
    end
  end
end
