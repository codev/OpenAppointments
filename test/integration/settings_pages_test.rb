require "test_helper"

class SettingsPagesTest < ActionDispatch::IntegrationTest
  # Pages gated on system_settings (admin only in the default roles).
  SYSTEM_SETTINGS_PAGES = %w[
    general_settings business_settings booking_settings theme_settings legal_settings api_settings
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
    customer = users(:jx)
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

  test "side menu shows the current page as text and marks a parent of the current page" do
    login_admin
    get "/booking_settings"
    assert_select "#settings-nav span.nav-link", text: /Booking Settings/
    assert_select "#settings-nav a[href='/booking_settings']", count: 0
    assert_select "#settings-nav a[href='/general_settings']"

    get "/ldap_settings"
    assert_select "#settings-nav a.fw-bold[href='/integrations']"

    get "/messages_twilio_settings"
    assert_select "#messages-nav a.fw-bold[href='/messages_providers']"
  end

  test "fixing the timezone moves every user to the default and hides the controls" do
    login_admin
    users(:zane).update!(timezone: "America/New_York")
    post "/general_settings/save", params: {
      general_settings: [ { name: "default_timezone", value: "Europe/London" }, { name: "fixed_timezone", value: "1" } ]
    }
    assert_response :success
    assert_equal "Europe/London", users(:zane).reload.timezone

    get "/providers"
    assert_select "div.d-none label[for='timezone']"
    get "/booking"
    assert_select "div.d-none label[for='select-timezone']"
    assert_match '"fixed_timezone":true', response.body
  end

  test "message failure report addresses default to the admins and must be valid" do
    login_admin
    get "/messages_settings"
    assert_match User.admins.first.email, response.body

    post "/messages_settings/save", params: {
      messages_settings: [ { name: "messages_failure_alert_emails", value: "a@example.org; not-an-email" } ]
    }
    assert_equal false, response.parsed_body["success"]
    assert_match "not-an-email", response.parsed_body["message"]

    post "/messages_settings/save", params: {
      messages_settings: [ { name: "messages_failure_alert_emails", value: "a@example.org, b@example.org" } ]
    }
    assert_equal true, response.parsed_body["success"]
    assert_equal "a@example.org, b@example.org", Setting.get("messages_failure_alert_emails")
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
    provider = users(:zane)
    post "/account/save", params: {
      account: {
        name: "Janet Doe", email: "zane@example.org",
        timezone: "Europe/London", language: "english",
        settings: { username: "janedoe", notifications: 1 }
      }
    }
    assert_response :success
    assert_equal true, response.parsed_body["success"]
    assert_equal "Janet Doe", provider.reload.name
  end

  test "account validate_username reports duplicates" do
    login_provider
    post "/account/validate_username", params: { username: "administrator", user_id: users(:zane).id }
    assert_equal false, response.parsed_body["is_valid"]

    post "/account/validate_username", params: { username: "janedoe", user_id: users(:zane).id }
    assert_equal true, response.parsed_body["is_valid"]
  end
end
