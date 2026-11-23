require "capybara/selenium/driver"
require "capybara/selenium/driver_specializations/chrome_driver"

# Capybara 3.40.0 (the latest release) resets Chrome between examples with the DevTools command
# `Storage.clearDataForOrigin` and `origin: "*"`. Chrome 158 rejects "*" ("invalid argument: * is not a valid URL"),
# which fails every JS system spec in teardown. When Chrome refuses it, clear cookies browser-wide and the app
# server's own origin instead; that is all the specs use. Older Chrome versions accept "*" and never reach the
# fallback. Remove this once Capybara clears storage another way.
module CapybaraChromeWildcardResetFallback
  def execute_cdp(cmd, params = {})
    super
  rescue ::Selenium::WebDriver::Error::InvalidArgumentError
    raise unless cmd == "Storage.clearDataForOrigin" && params[:origin] == "*"

    super("Storage.clearCookies")
    origin = ::Capybara.current_session.server&.base_url
    super(cmd, params.merge(origin: origin)) if origin
  end
end

::Capybara::Selenium::Driver::ChromeDriver.prepend(CapybaraChromeWildcardResetFallback)
