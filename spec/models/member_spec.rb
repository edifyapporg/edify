require "rails_helper"

describe ::Member do
  let(:member) { members(:bartell_randal) }

  describe "#age" do
    before { travel_to "2022-04-15" }

    it "returns the age based on birthdate" do
      expect(member.age).to eq(25)
    end
  end

  describe "#bio" do
    before { travel_to "2022-04-15" }

    it "returns the gender and age in a single string" do
      expect(member.bio).to eq("Male, 25")
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
    context "when the member is below youth age" do
      let(:member) { Member.new(birthdate: 10.years.ago) }
      it { expect(result).to eq(true) }
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
end
