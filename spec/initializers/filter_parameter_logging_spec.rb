require "rails_helper"

RSpec.describe "Log filtering" do
  let(:filter) { ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters) }

  it "filters OAuth codes and PKCE verifiers, but not other names containing code" do
    filtered = filter.filter("code" => "abc", "code_verifier" => "def", "zip_code" => "84101", "code_challenge" => "x")

    expect(filtered).to eq("code" => "[FILTERED]", "code_verifier" => "[FILTERED]", "zip_code" => "84101",
                           "code_challenge" => "x")
  end

  it "filters redirects that carry an authorization code" do
    redirect_filters = Rails.application.config.filter_redirect

    expect(redirect_filters).to(be_any { |pattern| pattern.match?("https://claude.ai/api/mcp/auth_callback?code=abc&state=s") })
    expect(redirect_filters).not_to(be_any { |pattern| pattern.match?("https://www.edifyapp.org/meetings?zip_code=1") })
  end
end
