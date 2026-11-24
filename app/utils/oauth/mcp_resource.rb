module Oauth
  # Edify's MCP endpoint as an OAuth protected resource (RFC 8707, RFC 9728). Edify's authorization server issues
  # tokens for this one resource only, so a client that names any other resource is refused with invalid_target.
  module McpResource
    PATH = "/mcp".freeze

    # @param request [ActionDispatch::Request]
    # @return [String] the MCP endpoint's URL on the host the request arrived at, e.g. https://www.edifyapp.org/mcp
    def self.url(request)
      "#{request.base_url}#{PATH}"
    end

    # @param request [ActionDispatch::Request]
    # @return [String] where the MCP endpoint's protected resource metadata is served (RFC 9728 path insertion)
    def self.metadata_url(request)
      "#{request.base_url}/.well-known/oauth-protected-resource#{PATH}"
    end

    # @param value [String] a client's `resource` parameter
    # @param request [ActionDispatch::Request]
    # @return [Boolean] true when it names /mcp on this request's host, or on production's www or bare domain
    def self.matches?(value, request)
      candidate = normalize(value)
      candidate.present? && acceptable_urls(request).include?(candidate)
    end

    def self.acceptable_urls(request)
      production = ::EdifyMcp::Server.allowed_hosts.map { |host| "https://#{host}#{PATH}" }
      [url(request), *production].map { |url| normalize(url) }
    end
    private_class_method :acceptable_urls

    # Lowercases the scheme and host, drops a trailing slash, and refuses a query or fragment.
    def self.normalize(value)
      uri = ::URI.parse(value.to_s)
      return if uri.host.nil? || uri.query || uri.fragment

      uri.scheme = uri.scheme.downcase
      uri.host = uri.host.downcase
      uri.to_s.delete_suffix("/")
    rescue ::URI::InvalidURIError
      nil
    end
    private_class_method :normalize
  end
end
