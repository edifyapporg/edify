# Edify's MCP endpoint (#322), for AI assistants answering leaders' questions. The MCP SDK's transport handles the
# protocol and the bearer token; see EdifyMcp::Server. Each POST is self-contained and answered with plain JSON.
class McpController < ActionController::API
  REQUESTS_PER_MINUTE = 60

  # Counted per token (hashed), so one assistant's burst does not slow another leader's.
  rate_limit to: REQUESTS_PER_MINUTE,
             within: 1.minute,
             by: -> { ::Digest::SHA256.hexdigest(request.authorization.to_s) },
             with: -> { rate_limited },
             store: ::Rails.cache

  # GET, POST and DELETE /mcp. The transport answers GET and DELETE itself, since a stateless server has no streams
  # or sessions to open or end.
  def handle
    status, headers, body = ::EdifyMcp::Server.transport(request).handle_request(request)

    headers.each { |name, value| response.set_header(name, value) }
    self.status = status
    self.response_body = body
  end

  private

  def rate_limited
    render status: :too_many_requests, json: {
      jsonrpc: "2.0", id: nil,
      error: { code: -32_000, message: "Too many requests. Wait a minute and try again." },
    }
  end
end
