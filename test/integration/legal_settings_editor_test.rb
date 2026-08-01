require "test_helper"

class LegalSettingsEditorTest < ActionDispatch::IntegrationTest
  test "the backend layout points trumbowyg at the digested icon sprite" do
    post "/login/validate", params: { username: "administrator", password: "administrator1" }
    get "/legal_settings"
    assert_response :success
    assert_match %r{jQuery\.trumbowyg\.svgPath = "/assets/vendor/trumbowyg/ui/icons-[a-f0-9]+\.svg"},
                 response.body
  end
end
