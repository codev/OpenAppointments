require "test_helper"

# The admin header shows the company logo from General Settings, falling back
# to the app logo when none is uploaded.
class BackendHeaderLogoTest < ActionDispatch::IntegrationTest
  LOGO = "data:image/png;base64,iVBORw0KGgo=".freeze

  def login_admin
    post "/login/validate", params: { username: "administrator", password: "administrator1" }
  end

  test "the company logo is shown top left" do
    Setting.set("company_logo", LOGO)
    login_admin
    get "/calendar"
    assert_select "#header-logo img[src^=?]", "/company_logo?v="
  end

  test "the app logo is shown when no company logo is set" do
    Setting.set("company_logo", "")
    login_admin
    get "/calendar"
    assert_select "#header-logo img[src*=?]", "/assets/logo"
  end
end
