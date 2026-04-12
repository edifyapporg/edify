class UnitAccessRejectionJob < ::ApplicationJob
  queue_as :default

  def perform(unit:, user:)
    ::UnitAccessRejectionNotification.with(user: user).deliver(unit.users.approvers)
  end
end
