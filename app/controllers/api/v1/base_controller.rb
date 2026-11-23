module Api
  module V1
    # The base for Edify's JSON API (#315). Every request authenticates with a personal access token sent as
    # `Authorization: Bearer <token>`. The user, and from them the unit, come only from that token, never from the URL
    # or parameters. Every action is authorized with Pundit, and every error has the shape
    # `{ "error": { "code": ..., "message": ... } }`.
    class BaseController < ::ActionController::API
      include ::Pundit::Authorization

      BEARER_PATTERN = /\ABearer (\S+)\z/

      before_action :authenticate_api_token!
      after_action :verify_authorized, except: :route_not_found

      rescue_from ::ActiveRecord::RecordNotFound, with: :record_not_found
      rescue_from ::Pundit::NotAuthorizedError, with: :not_authorized

      attr_reader :current_api_token

      # Matches any /api/v1 path no other route does, so unknown paths get the same error shape.
      def route_not_found
        render_error(:not_found, "not_found", "No such endpoint.")
      end

      private

      def current_user
        current_api_token&.user
      end

      def current_unit
        current_user&.unit
      end

      def authenticate_api_token!
        token = ::ApiToken.authenticate(bearer_token)

        if token.nil?
          response.headers["WWW-Authenticate"] = 'Bearer realm="Edify"'
          render_error(:unauthorized, "invalid_token", "Send a valid API token as 'Authorization: Bearer <token>'.")
        elsif !token.scope?(:read)
          render_error(:forbidden, "insufficient_scope", "This API token does not have read access.")
        elsif !token.user.assigned_to_unit?
          render_error(:forbidden, "no_unit", "Your Edify account is not assigned to a unit.")
        else
          token.touch_last_used!
          @current_api_token = token
        end
      end

      def bearer_token
        request.authorization.to_s[BEARER_PATTERN, 1]
      end

      def not_authorized
        render_error(:forbidden, "forbidden", "Your role does not have access to this.")
      end

      def record_not_found
        render_error(:not_found, "not_found", "Not found.")
      end

      def invalid_request(message)
        render_error(:unprocessable_content, "invalid_request", message)
      end

      def render_error(status, code, message)
        render json: { error: { code: code, message: message } }, status: status
      end
    end
  end
end
