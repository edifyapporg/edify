class UnitAccessApprovalJob < ::ApplicationJob
  queue_as :default

  def perform(unit:, user:)
    unit.users.approvers.find_each do |approver|
      ::UnitAccessApprovalNotification.with(user: user).deliver_later(approver)
    end
  end
end
