require "rails_helper"

describe ::Meeting do
  subject { described_class.new(date: date) }

  describe "#not_yet_occurred?" do
    let(:result) { subject.not_yet_occurred? }

    context "when the meeting is in the past" do
      let(:date) { 3.days.ago }
      it { expect(result).to eq(false) }
    end

    context "when the meeting is on the current date" do
      let(:date) { Date.current }
      it { expect(result).to eq(true) }
    end

    context "when the meeting is in the future" do
      let(:date) { 3.days.from_now }
      it { expect(result).to eq(true) }
    end
  end

  describe "#status" do
    let(:meeting) { meetings(:meeting_2) }
    let(:result) { meeting.status }

    before { meeting.talks.where(position: (talk_count + 1)..).delete_all }

    context "when a sacrament meeting has no talks" do
      let(:talk_count) { 0 }
      it { expect(result).to eq(:empty) }
    end

    context "when a sacrament meeting has fewer talks than the minimum" do
      let(:talk_count) { Meeting::MINIMUM_SPEAKERS - 1 }
      it { expect(result).to eq(:incomplete) }
    end

    context "when a sacrament meeting has exactly the minimum number of talks" do
      let(:talk_count) { Meeting::MINIMUM_SPEAKERS }
      it { expect(result).to eq(:ok) }
    end

    context "when a sacrament meeting has more talks than the minimum" do
      let(:talk_count) { 3 }
      it { expect(result).to eq(:ok) }
    end
  end
end
