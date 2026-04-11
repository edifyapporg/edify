class NotificationsController < ApplicationController
  before_action :authenticate_user!

  def index
    @notifications = current_user.notifications.newest_first
    @notifications.unread.mark_as_read
  end
end
