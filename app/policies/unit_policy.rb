class UnitPolicy < ApplicationPolicy
  def new?
    user.needs_onboarding?
  end

  def create?
    new?
  end

  def song_last_sung?
    user.music_editor? && own_unit?
  end

  def speaker_last_spoke?
    user.unit_admin? && own_unit?
  end

  private

  def own_unit?
    record.present? && user.unit_id == record.id
  end
end
