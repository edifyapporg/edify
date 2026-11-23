module Settings
  # Lets a user create, list and revoke their own personal access tokens for the API, CLI and MCP endpoint (#315).
  class ApiTokensController < ::ApplicationController
    before_action :authenticate_user!
    after_action :verify_authorized

    # GET /settings/api_tokens
    def index
      authorize ::ApiToken
      @api_token = new_api_token
      @api_tokens = policy_scope(::ApiToken).newest_first
    end

    # POST /settings/api_tokens
    # Renders the index rather than redirecting so the plaintext token can be shown once without passing it through
    # the session cookie or flash.
    def create
      authorize ::ApiToken
      @api_token = new_api_token
      @api_token.assign_attributes(api_token_params)

      if @api_token.save
        @created_token = @api_token
        @api_token = new_api_token
        status = :created
      else
        status = :unprocessable_content
      end

      @api_tokens = policy_scope(::ApiToken).newest_first
      render :index, status: status
    end

    # PATCH /settings/api_tokens/:id/revoke
    def revoke
      api_token = policy_scope(::ApiToken).find(params.expect(:id))
      authorize api_token

      api_token.revoke!
      redirect_to settings_api_tokens_path, notice: "Revoked \"#{api_token.name}\".", status: :see_other
    end

    private

    # Starts from the default expiry, so a request that leaves expires_in out gets that rather than a token that never
    # expires. A submitted code, valid or not, replaces it.
    def new_api_token
      ::ApiToken.new(user: current_user, expires_in: ::ApiToken::DEFAULT_EXPIRY)
    end

    def api_token_params
      params.expect(api_token: [:name, :expires_in])
    end
  end
end
