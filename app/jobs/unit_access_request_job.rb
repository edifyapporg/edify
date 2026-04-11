class UnitAccessRequestJob < ::ApplicationJob
  queue_as :default

  def perform(unit:, user:)
    unit.users.approvers.find_each do |approver|
      ::UnitAccessRequestNotification.with(user: user).deliver_later(approver)
    end
  end
end
