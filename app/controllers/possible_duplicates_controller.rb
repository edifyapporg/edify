class PossibleDuplicatesController < ApplicationController
  before_action :authenticate_user!
  after_action :verify_authorized

  # GET /possible_duplicates
  def index
    authorize :possible_duplicate, :index?
    @pairs = DuplicateMemberFinder.call(current_unit)
  end

  # PUT /possible_duplicates/merge
  def merge
    authorize :possible_duplicate, :merge?
    keep = current_unit.members.find(params.expect(:keep_id))
    remove = current_unit.members.find(params.expect(:remove_id))

    MergeMembers.call(keep: keep, remove: remove)
    remove_pair_response(keep, remove, notice: "Merged #{remove.name} into #{keep.name}.")
  end

  # POST /possible_duplicates/dismiss
  def dismiss
    authorize :possible_duplicate, :dismiss?
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
    frame_id = "duplicate_pair_#{[first.id, second.id].minmax.join('-')}"

    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.remove(frame_id) }
      format.html { redirect_to possible_duplicates_path, notice: notice }
    end
  end
end
