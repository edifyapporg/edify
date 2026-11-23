require "rails_helper"

RSpec.describe ::Members::StaleSpeakers do
  let(:unit) { units(:sunny_hills) }
  let!(:never_spoke) { member("Never, Spoke") }
  let!(:spoke_long_ago) { member("Long, Ago").tap { talk(it, on: 3.years.ago.to_date) } }
  let!(:spoke_last_year) { member("Last, Year").tap { talk(it, on: 14.months.ago.to_date) } }
  let!(:spoke_recently) { member("Recent, Talk").tap { talk(it, on: 2.months.ago.to_date) } }
  let!(:scheduled) do
    member("Scheduled, Soon").tap do |scheduled_member|
      talk(scheduled_member, on: 3.years.ago.to_date)
      talk(scheduled_member, on: 2.weeks.from_now.to_date)
    end
  end
  let!(:paused) { member("Paused, Member", paused_until: 1.month.from_now.to_date).tap { talk(it, on: 3.years.ago) } }
  let!(:pause_over) { member("Pause, Over", paused_until: 1.day.ago.to_date).tap { talk(it, on: 3.years.ago) } }
  let(:roster) do
    unit.members.where(id: [never_spoke, spoke_long_ago, spoke_last_year, spoke_recently, scheduled,
                            paused, pause_over,].map(&:id))
  end

  def member(name, **attributes)
    unit.members.create!(name: name, gender: :female, birthdate: "1980-01-01", **attributes)
  end

  def talk(member, on:)
    meeting = unit.meetings.find_or_create_by!(date: on) { |m| m.meeting_type = :sacrament_meeting }
    meeting.talks.create!(speaker_name: member.name, member: member)
  end

  def result(**)
    described_class.call(members: roster, **)
  end

  it "lists members who have not spoken in a year, longest-waiting first" do
    expect(result.map(&:name)).to eq(["Never, Spoke", "Long, Ago", "Pause, Over", "Last, Year"])
  end

  it "gives each member's last talk date, or nil if they have never spoken" do
    dates = result.to_h { [it.name, it.last_talk_date] }
    expect(dates["Never, Spoke"]).to be_nil
    expect(dates["Last, Year"]).to eq(14.months.ago.to_date)
  end

  it "treats a talk already scheduled as the member's last talk" do
    expect(result.map(&:name)).not_to include("Scheduled, Soon")
  end

  it "leaves out members whose invitations are paused, but not once the pause has ended" do
    expect(result.map(&:name)).not_to include("Paused, Member")
    expect(result.map(&:name)).to include("Pause, Over")
  end

  it "uses the number of months asked for" do
    expect(result(months: 1).map(&:name)).to include("Recent, Talk")
    expect(result(months: 24).map(&:name)).to eq(["Never, Spoke", "Long, Ago", "Pause, Over"])
  end

  it "returns at most the limit" do
    expect(result(limit: 2).map(&:name)).to eq(["Never, Spoke", "Long, Ago"])
  end

  it "searches only the roster it is given" do
    other = units(:pleasant_forest).members.create!(name: "Other, Unit", gender: :male, birthdate: "1980-01-01")
    names = described_class.call(members: unit.members, limit: 200).map(&:name)
    expect(names).to include("Never, Spoke")
    expect(names).not_to include(other.name)
  end

  it "rejects months and limits outside the allowed ranges" do
    expect { result(months: 0) }.to raise_error(ArgumentError, /months/)
    expect { result(months: 121) }.to raise_error(ArgumentError, /months/)
    expect { result(limit: 0) }.to raise_error(ArgumentError, /limit/)
    expect { result(limit: 201) }.to raise_error(ArgumentError, /limit/)
  end

  describe "filtering by group" do
    let!(:primary_child) { member("Primary, Child", birthdate: 9.years.ago.to_date) }
    let!(:youth) { member("Youth, Member", birthdate: 15.years.ago.to_date) }
    let(:roster) { unit.members.where(id: [never_spoke, primary_child, youth].map(&:id)) }

    it "returns everyone without a group" do
      expect(result.map(&:name)).to contain_exactly("Never, Spoke", "Primary, Child", "Youth, Member")
    end

    it "returns only the group asked for" do
      expect(result(group: "primary").map(&:name)).to eq(["Primary, Child"])
      expect(result(group: "youth").map(&:name)).to eq(["Youth, Member"])
      expect(result(group: "adult").map(&:name)).to eq(["Never, Spoke"])
    end

    it "names each member's group the way clients see it" do
      expect([primary_child, youth, never_spoke].map { described_class.group_of(it) }).to eq(%w[primary youth adult])
    end

    it "rejects an unknown group" do
      expect { result(group: "child") }.to raise_error(ArgumentError, /group must be one of primary, youth, adult/)
    end
  end
end
