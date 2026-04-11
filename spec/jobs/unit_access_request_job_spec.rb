require "rails_helper"

RSpec.describe UnitAccessRequestJob, type: :job do
  subject { described_class.new }

  let(:unit) { units(:sunny_hills) }
  let(:user) { users(:sunny_bishopric) }

  it "enqueues the job" do
    expect { described_class.perform_later(unit: unit, user: user) }.to have_enqueued_job(described_class)
  end

  describe "#perform" do
    let(:perform_job) { subject.perform(unit: unit, user: user) }

    before { allow(::UnitAccessRequestNotification).to receive(:deliver_later) }

    it "delivers a message to each approver" do
      mock_notification = instance_double(UnitAccessRequestNotification)
      allow(UnitAccessRequestNotification).to receive(:with).with(user: user).and_return(mock_notification)
      unit.users.approvers.each do |approver|
        expect(mock_notification).to receive(:deliver_later).with(approver)
      end

      perform_job
    end
  end
end
