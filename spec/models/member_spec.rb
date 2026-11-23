require "rails_helper"

describe ::Member do
  let(:member) { members(:bartell_randal) }

  describe "#age_this_year" do
    before { travel_to "2022-04-15" }

    it "returns the age the member turns this calendar year" do
      expect(member.age_this_year).to eq(25)
    end
  end

  describe "#bio" do
    before { travel_to "2022-04-15" }

    it "returns the gender and the age the member turns this year" do
      expect(member.bio).to eq("Male, turns 25 this year")
    end

    it "returns only the gender when the birth year is unknown" do
      member.birth_year = nil
      expect(member.bio).to eq("Male")
    end
  end

  describe "birthdate" do
    let(:unit) { units(:sunny_hills) }

    it "keeps only the year of a full birthdate" do
      created = unit.members.create!(name: "Year, Only", gender: :female, birthdate: "12 Mar 1991")

      expect(created.reload.birth_year).to eq(1991)
      expect(created.birthdate).to be_nil
    end

    it "leaves the birth year alone when a blank birthdate is given" do
      member.update!(birthdate: "")
      expect(member.reload.birth_year).to eq(1997)
    end

    it "checks the minimum speaker age against the exact date" do
      eight_tomorrow = (described_class::MINIMUM_SPEAKER_AGE.years.ago + 1.day).to_date
      young = unit.members.new(name: "Young, Not Yet", gender: :male, birthdate: eight_tomorrow)

      expect(young).not_to be_valid
      expect(young.errors.full_messages).to include("Birthdate member is not old enough")
    end

    it "checks the minimum speaker age by year when only a birth year is given" do
      turns_eight = unit.members.new(name: "Year, Eight", gender: :male, birth_year: Date.current.year - 8)
      turns_seven = unit.members.new(name: "Year, Seven", gender: :male, birth_year: Date.current.year - 7)

      expect(turns_eight).to be_valid
      expect(turns_seven).not_to be_valid
      expect(turns_seven.errors.full_messages).to include("Birth year member is not old enough")
    end

    it "refuses a birth year before 1900, in the future, or not a whole number" do
      [1899, Date.current.year + 1, "1990.5"].each do |year|
        expect(unit.members.new(name: "Odd, Year", gender: :male, birth_year: year)).not_to be_valid
      end
    end

    it "allows the same name and birth year in different units, but not in one" do
      other_unit = units.find { it != member.unit }

      expect(other_unit.members.new(name: member.name, gender: :male, birth_year: 1997)).to be_valid
      expect(member.unit.members.new(name: member.name, gender: :male, birth_year: 1997)).not_to be_valid
    end
  end

  describe "#created_on_first_sync?" do
    let(:result) { member.created_on_first_sync? }
    let(:unit) { member.unit }

    context "when the member was created on the date of the first sync" do
      before { member.update(created_at: unit.first_synced_on) }

      it { expect(result).to eq(true) }

      context "when the member was created after the date of the first sync" do
        before { member.update(created_at: unit.first_synced_on + 30.days) }

        it { expect(result).to eq(false) }
      end
    end
  end

  describe "#last_talk_date" do
    let(:result) { member.last_talk_date }
    context "when the member has never given a talk" do
      let(:member) { members(:bartell_randal) }
      it "returns nil" do
        expect(result).to be_nil
      end
    end

    context "when the member has given a single talk" do
      let(:member) { members(:barrows_kenneth) }
      it "returns the talk date" do
        expect(result).to eq("2022-04-10".to_date)
      end
    end

    context "when the member has given multiple talks" do
      let(:member) { members(:hill_waylon) }
      it "returns the most recent talk date" do
        expect(result).to eq("2022-04-10".to_date)
      end
    end
  end

  describe "#new_member?" do
    let(:result) { member.new_member? }
    let(:unit) { member.unit }

    context "when the member was created on the date of the first sync" do
      before { member.update(created_at: unit.first_synced_on) }

      it { expect(result).to eq(false) }
    end

    context "when the member was created after the date of the first sync" do
      before { member.update(created_at: unit.first_synced_on + 10.days) }

      context "when a short time has passed" do
        before { travel_to("2022-05-15") }

        it { expect(result).to eq(true) }
      end

      context "when a long time has passed" do
        before { travel_to("2023-05-15") }

        it { expect(result).to eq(false) }
      end
    end
  end

  describe "#not_in_most_recent_sync?" do
    let(:result) { member.not_in_most_recent_sync? }
    let(:unit) { member.unit }

    before { unit.update(last_synced_on: "2022-04-15") }

    context "when the member was synced on the same day as the most recent unit sync" do
      before { member.update(synced_on: "2022-04-15") }

      it { expect(result).to eq(false) }
    end

    context "when the member was synced later than the most recent unit sync" do
      before { member.update(synced_on: "2022-04-20") }

      it { expect(result).to eq(false) }
    end

    context "when the member was synced earlier than the most recent unit sync" do
      before { member.update(synced_on: "2022-04-10") }

      it { expect(result).to eq(true) }
    end

    context "when the member was never synced" do
      before { member.update(synced_on: nil) }

      it { expect(result).to eq(true) }
    end

    context "when the unit has never been imported" do
      before do
        unit.update(last_synced_on: nil)
        member.update(synced_on: "2022-04-10")
      end

      it { expect(result).to eq(false) }
    end
  end

  describe ".synced_since" do
    subject(:filtered) { unit.members.synced_since(unit.last_synced_on) }

    let(:unit) { units(:sunny_hills) }
    let(:current_member) { members(:bartell_randal) } # synced_on == unit.last_synced_on
    let(:moved_member) { members(:hill_waylon) } # synced_on before unit.last_synced_on
    let(:never_synced_member) { members(:user_unassigned) } # synced_on is nil

    it "keeps only members synced in the most recent import" do
      expect(filtered).to include(current_member)
      expect(filtered).not_to include(moved_member, never_synced_member)
      expect(filtered.none?(&:not_in_most_recent_sync?)).to be(true)
    end
  end

  describe "#paused?" do
    let(:result) { member.paused? }
    before { travel_to("2022-04-15") }

    context "when the member has no paused_until date" do
      before { member.update(paused_until: nil) }

      it { expect(result).to eq(false) }
    end

    context "when the member has a paused_until date that is before the current date" do
      before { member.update(paused_until: "2022-03-15") }

      it { expect(result).to eq(false) }
    end

    context "when the member has a paused_until date that is after the current date" do
      before { member.update(paused_until: "2022-05-15") }

      it { expect(result).to eq(true) }
    end
  end

  describe "#time_in_unit" do
    let(:result) { member.time_in_unit }
    let(:unit) { member.unit }

    before { travel_to("2022-05-15") }

    context "when the member was created on the date of the first sync" do
      before { member.update(created_at: unit.first_synced_on) }

      it { expect(result).to be_nil }
    end

    context "when the member was created after the date of the first sync" do
      before { member.update(created_at: unit.first_synced_on + 10.days) }

      it "returns the time from creation until now" do
        expect(result).to eq(12.days)
      end
    end
  end

  describe "#under_age?" do
    let(:result) { member.under_age? }

    context "when the member is below the minimum speaker age" do
      let(:member) { Member.new(birthdate: 7.years.ago) }
      it { expect(result).to eq(true) }
    end

    context "when the member has just reached the minimum speaker age" do
      let(:member) { Member.new(birthdate: Member::MINIMUM_SPEAKER_AGE.years.ago) }
      it { expect(result).to eq(false) }
    end

    context "when the member has reached it but is not yet in the youth programs" do
      let(:member) { Member.new(birthdate: 10.years.ago) }
      it { expect(result).to eq(false) }
    end

    context "when the member is youth age" do
      let(:member) { Member.new(birthdate: 15.years.ago) }
      it { expect(result).to eq(false) }
    end

    context "when the member is older" do
      let(:member) { Member.new(birthdate: 90.years.ago) }
      it { expect(result).to eq(false) }
    end
  end

  describe "matching household entries" do
    let(:unit) { units(:sunny_hills) }
    let(:household) { unit.households.create!(name: "Newcomer, Alma & Beth") }

    it "claims an entry the household directory named before the member existed" do
      entry = household.household_members.create!(name: "Newcomer, Alma", position: 0, parent: true)

      member = unit.members.create!(name: "Newcomer, Alma", gender: :female, birthdate: 40.years.ago.to_date)

      expect(entry.reload.member).to eq(member)
    end

    it "claims an entry when a member is renamed onto it" do
      entry = household.household_members.create!(name: "Newcomer, Beth", position: 0)
      member = unit.members.create!(name: "Elsewhere, Beth", gender: :female, birthdate: 40.years.ago.to_date)
      expect(entry.reload.member).to be_nil

      member.update!(name: "Newcomer, Beth")

      expect(entry.reload.member).to eq(member)
    end

    it "releases the link rather than guessing when a namesake appears" do
      entry = household.household_members.create!(name: "Newcomer, Alma", position: 0)
      unit.members.create!(name: "Newcomer, Alma", gender: :female, birthdate: 40.years.ago.to_date)
      expect(entry.reload.member).to be_present

      unit.members.create!(name: "Newcomer, Alma", gender: :female, birthdate: 41.years.ago.to_date)

      expect(entry.reload.member).to be_nil
    end

    it "claims the entry back once the duplicate is merged away" do
      entry = household.household_members.create!(name: "Newcomer, Alma", position: 0, parent: true)
      keep = unit.members.create!(name: "Newcomer, Alma", gender: :female, birthdate: 40.years.ago.to_date)
      dupe = unit.members.create!(name: "Newcomer, Alma", gender: :female, birthdate: 41.years.ago.to_date)
      expect(entry.reload.member).to be_nil

      Members::Merger.call(keep: keep, remove: dupe)

      expect(entry.reload.member).to eq(keep)
    end

    it "leaves an entry that is already matched alone" do
      taken = unit.members.create!(name: "Newcomer, Alma", gender: :female, birthdate: 40.years.ago.to_date)
      entry = household.household_members.create!(name: "Newcomer, Alma", position: 0, member: taken)

      taken.touch

      expect(entry.reload.member).to eq(taken)
    end
  end

  describe "#child?" do
    it "covers the minimum speaker age up to the youth programs, which start in the year a child turns 12" do
      expect(Member.new(birthdate: 9.years.ago)).to be_child
      expect(Member.new(birthdate: 11.years.ago.beginning_of_year)).to be_child
    end

    it "excludes anyone already in the youth programs" do
      expect(Member.new(birthdate: 13.years.ago)).not_to be_child
    end

    it "is false without a birthdate" do
      expect(Member.new(birthdate: nil)).not_to be_child
    end
  end

  describe "#speaker_category" do
    it "calls anyone not yet in the youth programs a child" do
      expect(Member.new(birthdate: 9.years.ago).speaker_category).to eq(:child)
      expect(Member.new(birthdate: (Member::YOUTH_AGE - 1).years.ago.beginning_of_year).speaker_category).to eq(:child)
    end

    it "calls anyone in the youth programs but not yet an adult a youth" do
      expect(Member.new(birthdate: 15.years.ago).speaker_category).to eq(:youth)
    end

    it "calls everyone else an adult" do
      expect(Member.new(birthdate: 40.years.ago).speaker_category).to eq(:adult)
      expect(Member.new(birthdate: nil).speaker_category).to eq(:adult)
    end
  end

  describe ".in_speaker_category" do
    # On 2026-06-15, children were born in 2015 or later, and youth in 2009 through 2014.
    around { |example| travel_to(Date.new(2026, 6, 15)) { example.run } }

    let(:unit) { units(:sunny_hills) }
    let!(:members_by_birth_year) do
      [2018, 2015, 2014, 2009, 2008, 1980].index_with do |year|
        unit.members.create!(name: "Born, #{year}", gender: :female, birth_year: year)
      end
    end
    let!(:no_birth_year) do
      unit.members.create!(name: "Born, Unknown", gender: :male, birth_year: 1980).tap do |member|
        member.update_column(:birth_year, nil)
      end
    end
    let(:members) { unit.members.where(id: [*members_by_birth_year.values, no_birth_year].map(&:id)) }

    def birth_years_in(category)
      members.in_speaker_category(category).map(&:birth_year)
    end

    it "splits members at the January cutoffs" do
      expect(birth_years_in(:child)).to contain_exactly(2018, 2015)
      expect(birth_years_in(:youth)).to contain_exactly(2014, 2009)
      expect(birth_years_in(:adult)).to contain_exactly(2008, 1980, nil)
    end

    it "agrees with #speaker_category for every member" do
      %i[child youth adult].each do |category|
        expect(members.in_speaker_category(category).map(&:speaker_category).uniq).to eq([category])
      end
      expect(%i[child youth adult].sum { members.in_speaker_category(it).count }).to eq(members.count)
    end

    it "rejects an unknown category" do
      expect { members.in_speaker_category(:primary) }.to raise_error(ArgumentError, /unknown speaker category/)
    end
  end

  describe "#parents" do
    let(:unit) { units(:sunny_hills) }
    let(:household) { unit.households.create!(name: "Hill, Waylon & Wanda") }
    let(:child) { unit.members.create!(name: "Hill, Junior", gender: :male, birthdate: 9.years.ago.to_date) }
    let(:parent) { unit.members.create!(name: "Hill, Wanda", gender: :female, birthdate: 40.years.ago.to_date) }

    it "returns the adults their household is named for" do
      household.household_members.create!(name: parent.name, member: parent, position: 0, parent: true)
      household.household_members.create!(name: child.name, member: child, position: 1, listed_age: 9)

      expect(child.parents).to eq([parent])
    end

    it "never includes the member themselves" do
      household.household_members.create!(name: parent.name, member: parent, position: 0, parent: true)

      expect(parent.parents).to be_empty
    end

    it "is empty without a household" do
      expect(child.parents).to be_empty
    end
  end

  describe ".matching_name" do
    let(:unit) { units(:sunny_hills) }
    let!(:jane) { unit.members.create!(name: "Smithson, Jane Marie", gender: :female, birthdate: "1980-01-01") }
    let!(:john) { unit.members.create!(name: "Smith, John", gender: :male, birthdate: "1980-01-01") }
    let!(:percent) { unit.members.create!(name: "Odd 100% Name", gender: :male, birthdate: "1980-01-01") }

    def names_for(query)
      unit.members.where(id: [jane, john, percent].map(&:id)).matching_name(query).pluck(:name)
    end

    it "matches every word, in any order, ignoring case" do
      expect(names_for("jane smith")).to eq(["Smithson, Jane Marie"])
      expect(names_for("SMITH")).to contain_exactly("Smithson, Jane Marie", "Smith, John")
      expect(names_for("john marie")).to be_empty
    end

    it "treats LIKE wildcards in the query as plain characters" do
      expect(names_for("%")).to eq(["Odd 100% Name"])
      expect(names_for("_")).to be_empty
    end
  end

  describe "#age_group" do
    it "names each speaker category as clients do" do
      expect(Member.new(birthdate: 9.years.ago).age_group).to eq("primary")
      expect(Member.new(birthdate: 15.years.ago).age_group).to eq("youth")
      expect(Member.new(birthdate: 40.years.ago).age_group).to eq("adult")
    end
  end
end
