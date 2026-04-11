require "rails_helper"

describe CheckMeetingsAndNotify do
  subject { described_class.new(unit) }

  let(:unit) { units(:sunny_hills) }

  before do
    travel_to(test_date)
  end

  context "when there are unscheduled meetings in the relevant timeframe" do
    let(:test_date) { "2022-04-30" }

    it "sends notifications of missing dates to each meeting scheduler" do
      expect do
        subject.perform!
      end.to change(Noticed::Notification, :count).by_at_least(unit.users.meeting_schedulers.count)

      event = Noticed::Event.where(type: "MissingMeetingsNotification").last
      expect(event).to be_present
      expect(event.params[:dates]).to include(Date.new(2022, 5, 8), Date.new(2022, 5, 22))
    end
  end

  context "when there are no unscheduled meetings in the relevant timeframe" do
    let(:test_date) { "2022-04-01" }

    it "does not send missing meeting notifications" do
      expect do
        subject.perform!
      end.not_to(change { Noticed::Event.where(type: "MissingMeetingsNotification").count })
    end
  end

  context "when there are incomplete meetings in the relevant timeframe" do
    let(:test_date) { "2022-04-30" }
    let(:incomplete_meeting) { unit.meetings.find_by(date: "2022-05-15") }

    context "when the meeting has no scheduler" do
      it "sends an incomplete meeting notification to each meeting scheduler" do
        expect do
          subject.perform!
        end.to change { Noticed::Event.where(type: "IncompleteMeetingNotification").count }.by(1)

        event = Noticed::Event.where(type: "IncompleteMeetingNotification").last
        scheduler_ids = unit.users.meeting_schedulers.pluck(:id)
        recipient_ids = event.notifications.pluck(:recipient_id)
        expect(recipient_ids).to match_array(scheduler_ids)
      end
    end

    context "when the meeting has a scheduler" do
      let(:scheduler) { unit.users.first }

      before { incomplete_meeting.update(scheduler: scheduler) }

      it "sends an incomplete meeting notification to the scheduler" do
        subject.perform!

        event = Noticed::Event.where(type: "IncompleteMeetingNotification").last
        expect(event.notifications.pluck(:recipient_id)).to eq([scheduler.id])
      end
    end
  end

  context "when there are no incomplete meetings in the relevant timeframe" do
    let(:test_date) { "2022-04-01" }

    before do
      unit.meetings.find_by(date: "2022-04-17").update(meeting_type: :stake_conference)
      unit.meetings.find_by(date: "2022-04-24").update(meeting_type: :testimony_meeting)
    end

    it "does not send an incomplete meeting notification" do
      expect do
        subject.perform!
      end.not_to(change { Noticed::Event.where(type: "IncompleteMeetingNotification").count })
    end
  end
end
