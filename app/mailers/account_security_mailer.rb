class AccountSecurityMailer < ApplicationMailer
  # @param api_token [ApiToken] the token just created
  def api_token_created(api_token)
    @api_token = api_token
    @user = api_token.user
    mail(to: @user.email)
  end

  # @param user [User] the leader who chose Allow on the OAuth consent screen
  # @param application [OauthApplication] the client they allowed
  # @param loopback [Boolean] whether the client finished connecting on the leader's own computer, as Claude Code does
  def app_connected(user, application, loopback:)
    @user = user
    @application = application
    @loopback = loopback
    mail(to: @user.email)
  end
end
