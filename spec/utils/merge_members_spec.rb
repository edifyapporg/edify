require "rails_helper"

describe ::MergeMembers do
  let(:unit) { units(:sunny_hills) }

  let(:keep) do
    unit.members.create!(name: "Kept, Person", gender: :female, birthdate: "1990-01-01",
                         synced_on: Date.current, email: nil, phone_number: nil)
  end
  let(:remove) do
    unit.members.create!(name: "Removed, Person", gender: :female, birthdate: "1990-01-01",
                         synced_on: 1.week.ago, email: "reachme@example.com", phone_number: "555-1212")
  end

  it "reassigns talks and notes to the kept record and deletes the other" do
    talk = meetings(:meeting_5).talks.create!(speaker_name: remove.name, member: remove, position: 99)
    note = remove.notes.create!(date: Date.current, content: "hello")

    described_class.call(keep: keep, remove: remove)

    expect(::Member.exists?(remove.id)).to be(false)
    expect(::Member.exists?(keep.id)).to be(true)
    expect(talk.reload.member_id).to eq(keep.id)
    expect(note.reload.member_id).to eq(keep.id)
  end

  it "backfills contact details that are missing on the kept record" do
    described_class.call(keep: keep, remove: remove)

    expect(keep.reload.email).to eq("reachme@example.com")
    expect(keep.phone_number).to eq("555-1212")
  end

  it "rolls back everything if the deletion fails" do
    note = remove.notes.create!(date: Date.current, content: "hello")
    allow(remove).to receive(:destroy!).and_raise(ActiveRecord::RecordNotDestroyed)

    expect { described_class.call(keep: keep, remove: remove) }.to raise_error(ActiveRecord::RecordNotDestroyed)

    expect(note.reload.member_id).to eq(remove.id)
    expect(::Member.exists?(remove.id)).to be(true)
  end

  it "refuses to merge a member into itself" do
    expect { described_class.call(keep: keep, remove: keep) }.to raise_error(ArgumentError)
  end
end
