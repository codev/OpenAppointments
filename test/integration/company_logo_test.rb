require "test_helper"

# The company logo is a data URL setting; pages link to /company_logo so the
# browser caches the image, and the digest in the link changes with the image.
class CompanyLogoTest < ActionDispatch::IntegrationTest
  PNG = Base64.decode64("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==").freeze
  LOGO = "data:image/png;base64,#{Base64.strict_encode64(PNG)}".freeze

  def login_admin
    post "/login/validate", params: { username: "administrator", password: "administrator1" }
  end

  test "the logo is served with a long cache life" do
    Setting.set("company_logo", LOGO)
    get "/company_logo"
    assert_response :success
    assert_equal "image/png", response.media_type
    assert_equal PNG, response.body
    assert_match(/public/, response.headers["Cache-Control"])
    assert_match(/max-age=31556952/, response.headers["Cache-Control"])
  end

  test "no logo or a malformed value is not found" do
    Setting.set("company_logo", "")
    get "/company_logo"
    assert_response :not_found
    Setting.set("company_logo", "not a data url")
    get "/company_logo"
    assert_response :not_found
  end

  test "pages link to the route with a digest that changes with the image" do
    Setting.set("company_logo", LOGO)
    first = CompanyLogo.path
    assert_match %r{\A/company_logo\?v=\h+\z}, first

    get "/booking"
    assert_select "#company-logo[src=?]", first

    login_admin
    get "/calendar"
    assert_select "#header-logo img[src=?]", first
    get "/general_settings"
    assert_select "#company-logo-preview[src=?]", first

    Setting.set("company_logo", "data:image/gif;base64,R0lGODlhAQABAAAAACw=")
    assert_not_equal first, CompanyLogo.path
    Setting.set("company_logo", "")
    assert_nil CompanyLogo.path
  end
end
