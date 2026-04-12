class UnitAccessApprovalJob < ::ApplicationJob
  queue_as :default

  def perform(unit:, user:)
    ::UnitAccessApprovalNotification.with(user: user).deliver(unit.users.approvers)
  end
end
