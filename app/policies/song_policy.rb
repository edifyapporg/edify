class SongPolicy < ApplicationPolicy
  # Every role in the unit sees the songs on the meetings index (MeetingPolicy#index?), so every role may ask which
  # have been sung recently.
  def recent?
    user.assigned_to_unit?
  end

  def new?
    user.music_editor?
  end

  def create?
    new?
  end

  def edit?
    new?
  end

  def update?
    new?
  end

  def destroy?
    new?
  end
end
