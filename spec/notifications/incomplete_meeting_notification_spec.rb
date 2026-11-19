require "rails_helper"

RSpec.describe IncompleteMeetingNotification do
  let(:unit) { units(:sunny_hills) }
  let(:recipient) { users(:sunny_bishopric) }
  let(:meeting) { unit.meetings.first }

  it "creates an event and notification" do
    expect do
      described_class.with(meeting: meeting).deliver(recipient)
    end.to change(Noticed::Event, :count).by(1)
                                         .and change(Noticed::Notification, :count).by(1)
  end

  describe "notification methods" do
    before { described_class.with(meeting: meeting).deliver(recipient) }

    let(:notification) { Noticed::Notification.last }

    it "returns the correct message" do
      expect(notification.message).to be_present
    end

    it "returns the correct subject" do
      expect(notification.subject).to be_present
    end

    it "returns the correct url" do
      expect(notification.url).to include("/meetings/")
    end
  end

  describe "the message for each number of speakers" do
    let(:meeting) { meetings(:meeting_2) }
    let(:message) { Noticed::Notification.last.message }

    before do
      meeting.talks.where(position: (talk_count + 1)..).delete_all
      described_class.with(meeting: meeting.reload).deliver(recipient)
    end

    context "when no speakers are scheduled" do
      let(:talk_count) { 0 }

      it { expect(message).to eq("The Sacrament Meeting scheduled for April 10 has no speakers yet scheduled.") }
    end

    context "when one speaker is scheduled" do
      let(:talk_count) { 1 }

      it "names the meeting type without repeating the word meeting" do
        expect(message).to eq("The Sacrament Meeting scheduled for April 10 has only one speaker scheduled at this time.")
      end
    end

    context "when more than one speaker is scheduled" do
      let(:talk_count) { 2 }

      it { expect(message).to eq("The Sacrament Meeting scheduled for April 10 has only 2 speakers scheduled at this time.") }
    end
  end
end
