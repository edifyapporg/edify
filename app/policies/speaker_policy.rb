# Headless policy for speaker questions asked through the API, resolved with `authorize :speaker, :stale?`. Last-talk
# dates already appear on the members index, so the same roles may see them here: the bishopric and clerks.
class SpeakerPolicy < ApplicationPolicy
  def stale?
    user.access_to_lcr?
  end
end
