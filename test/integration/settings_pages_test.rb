require "test_helper"

class SettingsPagesTest < ActionDispatch::IntegrationTest
  # Pages gated on system_settings (admin only in the default roles).
  SYSTEM_SETTINGS_PAGES = %w[
    general_settings business_settings booking_settings legal_settings api_settings
    altcha_settings google_calendar_settings google_analytics_settings
    matomo_analytics_settings jitsi_settings ldap_settings integrations
  ].freeze

  # Pages gated on user_settings (providers have access too).
  USER_SETTINGS_PAGES = %w[about account].freeze

  def login_admin
    post "/login/validate", params: { username: "administrator", password: "administrator1" }
  end

  def login_provider
    post "/login/validate", params: { username: "janedoe", password: "janedoe1" }
  end

  def login_customer
    customer = users(:james)
    customer.create_settings!(username: "jamesdoe", password: Passwords.hash("customer1"))
    post "/login/validate", params: { username: "jamesdoe", password: "customer1" }
  end

  test "admin can view every settings page" do
    login_admin
    (SYSTEM_SETTINGS_PAGES + USER_SETTINGS_PAGES).each do |page|
      get "/#{page}"
      assert_response :success, "expected 200 for admin on /#{page}"
    end
  end

  test "provider is forbidden from system settings pages but can view user settings pages" do
    login_provider
    SYSTEM_SETTINGS_PAGES.each do |page|
      get "/#{page}"
      assert_response :forbidden, "expected 403 for provider on /#{page}"
    end
    USER_SETTINGS_PAGES.each do |page|
      get "/#{page}"
      assert_response :success, "expected 200 for provider on /#{page}"
    end
  end

  test "customer is forbidden from every settings page" do
    login_customer
    (SYSTEM_SETTINGS_PAGES + USER_SETTINGS_PAGES).each do |page|
      get "/#{page}"
      assert_response :forbidden, "expected 403 for customer on /#{page}"
    end
  end

  test "general settings save persists whitelisted settings" do
    login_admin
    post "/general_settings/save", params: {
      general_settings: [
        { name: "company_name", value: "Open Out" },
        { name: "not_whitelisted", value: "ignored" }
      ]
    }
    assert_response :success
    assert_equal true, response.parsed_body["success"]
    assert_equal "Open Out", Setting.get("company_name")
    assert_nil Setting.get("not_whitelisted")
  end

  test "general settings save is forbidden without edit privilege" do
    login_provider
    post "/general_settings/save", params: { general_settings: [ { name: "company_name", value: "X" } ] }
    assert_response :internal_server_error
    assert_equal false, response.parsed_body["success"]
    assert_equal "Test Company", Setting.get("company_name")
  end

  test "account save persists the display name change" do
    login_provider
    provider = users(:jane)
    post "/account/save", params: {
      account: {
        name: "Janet Doe", email: "jane@example.org",
        timezone: "Europe/London", language: "english",
        settings: { username: "janedoe", calendar_view: "default", notifications: 1 }
      }
    }
    assert_response :success
    assert_equal true, response.parsed_body["success"]
    assert_equal "Janet Doe", provider.reload.name
  end

  test "account validate_username reports duplicates" do
    login_provider
    post "/account/validate_username", params: { username: "administrator", user_id: users(:jane).id }
    assert_equal false, response.parsed_body["is_valid"]

    post "/account/validate_username", params: { username: "janedoe", user_id: users(:jane).id }
    assert_equal true, response.parsed_body["is_valid"]
  end
end
