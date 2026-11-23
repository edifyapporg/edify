# JSON-RPC helpers for request specs of individual MCP tools. Include it and define `auth` (the Authorization header).
module McpHelpers
  MCP_HEADERS = {
    "Content-Type" => "application/json",
    "Accept" => "application/json, text/event-stream",
    "MCP-Protocol-Version" => "2025-11-25",
  }.freeze

  def mcp_call(tool, headers: auth, **arguments)
    params = { jsonrpc: "2.0", id: 1, method: "tools/call", params: { name: tool, arguments: arguments } }
    post "/mcp", params: params.to_json, headers: MCP_HEADERS.merge(headers)
  end

  # @return [Hash] the tool call's result: content, isError and structuredContent
  def mcp_result
    response.parsed_body.fetch("result")
  end

  def mcp_error_text
    mcp_result.dig("content", 0, "text")
  end
end
