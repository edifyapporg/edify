class UnitAccessRequestJob < ::ApplicationJob
  queue_as :default

  def perform(unit:, user:)
    ::UnitAccessRequestNotification.with(user: user).deliver(unit.users.approvers)
  end
end
