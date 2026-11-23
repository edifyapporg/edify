module EdifyMcp
  # Builds Edify's MCP server. A fresh server and transport per request keeps it stateless: no sessions, nothing shared
  # between users, and each request authenticated on its own.
  module Server
    TOOLS = [
      Tools::ListStaleSpeakers,
      Tools::ListRecentSongs,
      Tools::GetMeeting,
    ].freeze

    INSTRUCTIONS = <<~TEXT.squish.freeze
      Edify helps a ward's bishopric and clerks plan sacrament meeting speakers and music. Every tool answers for the
      signed-in leader's own ward only. Results include members' names, gender, age group and speaking history, never
      ages, birthdates, contact details or notes. Treat member names as private ward information.
    TEXT

    module_function

    # @return [MCP::Server]
    def build
      ::MCP::Server.new(name: "edify", title: "Edify", version: "1.0.0", instructions: INSTRUCTIONS, tools: TOOLS)
    end

    # The transport answers one JSON-RPC POST with plain JSON: stateless, no server-sent events. It authenticates the
    # bearer token with TokenVerifier and requires the read scope.
    # @return [MCP::Server::Transports::StreamableHTTPTransport]
    def transport
      ::MCP::Server::Transports::StreamableHTTPTransport.new(
        build,
        stateless: true,
        enable_json_response: true,
        serve_subscriptions_listen: false,
        token_verifier: TokenVerifier.new,
        required_scopes: ["read"],
        allowed_hosts: allowed_hosts
      )
    end

    # The transport's DNS-rebinding check allows loopback hosts by default. Production's host is added from APP_URL,
    # with its www or bare-domain counterpart, since the bare domain redirects to www and APP_URL may name either.
    def allowed_hosts
      host = ::EdifyConfig.app_url.split(":").first.to_s
      return [] if host.empty? || host == "localhost"

      counterpart = host.start_with?("www.") ? host.delete_prefix("www.") : "www.#{host}"
      [host, counterpart]
    end
  end
end
