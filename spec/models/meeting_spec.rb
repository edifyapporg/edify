require "rails_helper"

describe ::Meeting do
  subject { described_class.new(date: date) }

  describe "#status for meetings with no talks" do
    let(:meeting) { meetings(:meeting_6) }

    before { meeting.update!(meeting_type: meeting_type) }

    context "when it is a sacrament meeting" do
      let(:meeting_type) { :sacrament_meeting }
      it { expect(meeting.status).to eq(:empty) }
    end

    context "when it is a ward conference, which has speakers like a sacrament meeting" do
      let(:meeting_type) { :ward_conference }
      it { expect(meeting.status).to eq(:empty) }
    end

    context "when it is a meeting without assigned speakers" do
      let(:meeting_type) { :testimony_meeting }
      it { expect(meeting.status).to eq(:ok) }
    end
  end

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
end
