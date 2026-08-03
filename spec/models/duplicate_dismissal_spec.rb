require "rails_helper"

describe ::DuplicateDismissal do
  let(:unit) { units(:sunny_hills) }

  def create_member(name, birthdate: "1990-01-01")
    unit.members.create!(name: name, gender: :male, birthdate: birthdate, synced_on: Date.current)
  end

  describe ".for" do
    let(:lower) { create_member("Aaa, One") }
    let(:higher) { create_member("Bbb, Two") }

    it "normalizes member order by id regardless of argument order" do
      forward = described_class.for(lower, higher)
      reverse = described_class.for(higher, lower)

      expect(forward.member_a).to eq(lower)
      expect(forward.member_b).to eq(higher)
      expect(reverse.member_a).to eq(lower)
      expect(reverse.member_b).to eq(higher)
    end

    it "finds the existing dismissal for a pair given in either order" do
      described_class.for(lower, higher).tap do |d|
        d.unit = unit
        d.dismissed_by = 1
      end.save!

      expect(described_class.for(higher, lower)).to be_persisted
    end
  end

  it "is removed when a referenced member is deleted" do
    a = create_member("Aaa, One")
    b = create_member("Bbb, Two")
    described_class.for(a, b).tap do |d|
      d.unit = unit
      d.dismissed_by = 1
    end.save!

    expect { a.destroy }.to change(described_class, :count).by(-1)
  end
end
