require "rails_helper"

RSpec.describe UnitAccessApprovalJob, type: :job do
  subject { described_class.new }

  let(:unit) { units(:sunny_hills) }
  let(:user) { users(:sunny_bishopric) }

  it "enqueues the job" do
    expect { described_class.perform_later(unit: unit, user: user) }.to have_enqueued_job(described_class)
  end

  describe "#perform" do
    it "creates notifications for each approver" do
      expect do
        subject.perform(unit: unit, user: user)
      end.to change(Noticed::Notification, :count).by(unit.users.approvers.count)
    end

    it "delivers to the correct recipients" do
      subject.perform(unit: unit, user: user)

      approver_ids = unit.users.approvers.pluck(:id)
      recipient_ids = Noticed::Notification.last(approver_ids.size).map(&:recipient_id)
      expect(recipient_ids).to match_array(approver_ids)
    end
  end
end
