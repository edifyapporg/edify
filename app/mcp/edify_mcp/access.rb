module EdifyMcp
  # Who may use the MCP endpoint. Until the privacy review in #315 is done it is open to site admins only, unless
  # MCP_ENABLED=true opens it to every user with an API token. What each user can see is still decided by their role,
  # per tool.
  module Access
    module_function

    # @param user [User]
    def allowed?(user)
      user.admin? || ::EdifyConfig.mcp_enabled_for_everyone?
    end
  end
end
