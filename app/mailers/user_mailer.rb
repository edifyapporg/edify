class UserMailer < ApplicationMailer
  def incomplete_meeting_notification
    @notification = params[:notification]
    mail(
      to: params[:recipient].email,
      subject: @notification.subject,
    )
  end

  def missing_meetings_notification
    @notification = params[:notification]
    mail(
      to: params[:recipient].email,
      subject: @notification.subject,
    )
  end

  def new_user_admin_notification
    @notification = params[:notification]
    mail(
      to: params[:recipient].email,
      subject: @notification.subject,
    )
  end

  def new_user_notification
    @notification = params[:notification]
    mail(
      to: params[:recipient].email,
      subject: @notification.subject,
    )
  end

  def unit_access_approval_notification
    @notification = params[:notification]
    mail(
      to: params[:recipient].email,
      subject: @notification.subject,
      template_name: "unit_access_notification",
    )
  end

  def unit_access_rejection_notification
    @notification = params[:notification]
    mail(
      to: params[:recipient].email,
      subject: @notification.subject,
      template_name: "unit_access_notification",
    )
  end

  def unit_access_request_notification
    @notification = params[:notification]
    mail(
      to: params[:recipient].email,
      subject: @notification.subject,
      template_name: "unit_access_notification",
    )
  end
end
