class ImpersonateController < ApplicationController
  before_action :authenticate_user!

  def start
    return unless current_user.admin?

    user = User.find(params.expect(:id))
    impersonate_user(user)
    redirect_to root_path
  end

  def stop
    stop_impersonating_user
    redirect_to root_path
  end
end
