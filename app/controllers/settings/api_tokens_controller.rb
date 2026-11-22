module Settings
  # Lets a user create, list and revoke their own personal access tokens for the API, CLI and MCP endpoint (#315).
  class ApiTokensController < ::ApplicationController
    EXPIRY_CHOICES = {
      "30 days" => 30.days,
      "90 days" => 90.days,
      "1 year" => 1.year,
      "Never" => nil,
    }.freeze
    DEFAULT_EXPIRY = "90 days".freeze

    before_action :authenticate_user!
    after_action :verify_authorized

    # GET /settings/api_tokens
    def index
      authorize ::ApiToken
      @api_token = ::ApiToken.new
      @expires_in = DEFAULT_EXPIRY
      @api_tokens = policy_scope(::ApiToken).newest_first
    end

    # POST /settings/api_tokens
    # Renders the index rather than redirecting so the plaintext token can be shown once without passing it through
    # the session cookie or flash.
    def create
      authorize ::ApiToken
      @expires_in = EXPIRY_CHOICES.key?(api_token_params[:expires_in]) ? api_token_params[:expires_in] : DEFAULT_EXPIRY
      @api_token = ::ApiToken.new(user: current_user,
                                  name: api_token_params[:name],
                                  expires_at: EXPIRY_CHOICES[@expires_in]&.from_now)

      if @api_token.save
        @created_token = @api_token
        @api_token = ::ApiToken.new
        @expires_in = DEFAULT_EXPIRY
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

    def api_token_params
      params.expect(api_token: [:name, :expires_in])
    end
  end
end
