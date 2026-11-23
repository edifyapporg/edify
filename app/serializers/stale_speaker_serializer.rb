# A member in a list of stale speakers (Members::StaleSpeakers): name, gender, age group and last talk, and nothing
# else. Never an age, birthdate, contact details or notes (#315). See docs/api.md.
class StaleSpeakerSerializer
  # @param member [Member] one returned by Members::StaleSpeakers
  # @return [Hash]
  def self.call(member)
    {
      name: member.name,
      gender: member.gender,
      group: member.age_group,
      last_talk_date: member.last_talk_date,
    }
  end
end
