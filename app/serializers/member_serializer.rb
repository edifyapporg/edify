# A member found by name: their name, gender and age group, and nothing else. Never an age, birthdate, contact
# details, notes or member id (#315). See docs/api.md.
class MemberSerializer
  # @param member [Member]
  # @return [Hash]
  def self.call(member)
    {
      name: member.name,
      gender: member.gender,
      group: member.age_group,
    }
  end
end
