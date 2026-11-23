module EdifyMcp
  # Base for Edify's MCP tools. Each tool runs as the user who owns the API token, sees only that user's unit, is
  # authorized with the same Pundit policies as the API, and is logged with its arguments.
  class Tool < ::MCP::Tool
    class << self
      private

      # @return [User] the token's owner (TokenVerifier put their id in the subject)
      def current_user(server_context)
        ::User.find(server_context.auth_info.subject)
      end

      # Records who called which tool with what, but never the results, which hold member data.
      def log_call(server_context, arguments)
        auth_info = server_context.auth_info
        ::Rails.logger.info(
          "[mcp] tool=#{tool_name} user_id=#{auth_info.subject} token=#{auth_info.client_id} " \
          "arguments=#{arguments.compact.to_json}"
        )
      end

      # @param user [User]
      # @param query [Symbol] the policy method, e.g. :stale?
      # @param record [Object] what Pundit authorizes, e.g. :speaker for a headless policy
      def authorized?(user, record, query)
        ::Pundit.policy!(user, record).public_send(query)
      end

      # Answers with the data both as text, for clients that read only text, and as structured content.
      def respond_with(data)
        ::MCP::Tool::Response.new([{ type: "text", text: data.to_json }], structured_content: data)
      end

      def respond_with_error(message)
        ::MCP::Tool::Response.new([{ type: "text", text: message }], error: true)
      end

      def not_authorized
        respond_with_error("Your Edify role does not have access to this.")
      end
    end
  end
end
