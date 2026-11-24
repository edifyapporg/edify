# Be sure to restart your server when you modify this file.

# Configure parameters to be partially matched (e.g. passw matches password) and filtered from the log file.
# Use this to limit dissemination of sensitive information.
# See the ActiveSupport::ParameterFilter documentation for supported notations and behaviors.
Rails.application.config.filter_parameters += [
  :_key,
  :birthdate,
  :certificate,
  # OAuth (#323): the authorization code, matched exactly so names like zip_code still log, and the PKCE verifier.
  /\Acode\z/,
  :code_verifier,
  :crypt,
  :data_string,
  :otp,
  :passw,
  :phone_number,
  :salt,
  :secret,
  :ssn,
  :token,
  :username,
]

# The OAuth authorization step redirects the browser to the client with the code in the query string. Log those
# redirects as [FILTERED] rather than with a code a log reader could redeem.
Rails.application.config.filter_redirect << /[?&]code=/
