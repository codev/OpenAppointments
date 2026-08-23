require "application_system_test_case"

# Every settings page: change one field, save, see the confirmation and the
# stored value. Written against the jQuery pages before the Rails forms
# conversion (element ids only), so it must pass on both.
class SettingsPagesTest < ApplicationSystemTestCase
  TEXT_FIELDS = {
    "general_settings" => [ "company-name", "company_name", "Open Out Test" ],
    "business_settings" => [ "future-booking-limit", "future_booking_limit", "45" ],
    "api_settings" => [ "api-token", "api_token", "tok-123" ],
    "google_calendar_settings" => [ "google-client-id", "google_client_id", "client-1" ],
    "google_analytics_settings" => [ "google-analytics-code", "google_analytics_code", "G-1" ],
    "matomo_analytics_settings" => [ "matomo-analytics-url", "matomo_analytics_url", "https://m.example.org" ],
    "umami_analytics_settings" => [ "umami-analytics-url", "umami_analytics_url", "https://u.example.org" ],
    "ldap_settings" => [ "ldap-host", "ldap_host", "ldap.example.org" ],
    "messages_settings" => [ "messages-retention-days", "messages_retention_days", "45" ],
    "messages_email_settings" => [ "smtp-host", "messages_email_smtp_host", "smtp.example.org" ],
    "messages_smsgateway_settings" => [ "messages-smsgateway-url", "messages_smsgateway_url", "https://g.example.org" ],
    "messages_twilio_settings" => [ "messages-twilio-account-sid", "messages_twilio_account_sid", "AC1" ],
    "messages_plivo_settings" => [ "messages-plivo-auth-id", "messages_plivo_auth_id", "MA1" ],
    "messages_textanywhere_settings" => [ "messages-textanywhere-from", "messages_textanywhere_from", "OpenOut" ]
  }.freeze

  SWITCHES = {
    "booking_settings" => [ "display-email", "display_email" ],
    "altcha_settings" => [ "altcha-enabled", "altcha_enabled" ],
    "embed_settings" => [ "allow-iframe-embedding", "allow_iframe_embedding" ],
    "jitsi_settings" => [ "jitsi-enabled", "jitsi_enabled" ],
    "legal_settings" => [ "display-cookie-notice", "display_cookie_notice" ]
  }.freeze

  setup do
    # Old page validations: booking needs one required field, altcha needs its key.
    Setting.set("display_phone_number", "1")
    Setting.set("require_phone_number", "1")
    Setting.set("altcha_hmac_key", "k" * 32)
    login_as_admin
  end

  def save_and_check(page)
    find("#save-settings, #save-embed-settings").click
    assert_text "Settings saved", wait: 5
    yield
    visit "/#{page}"
  end

  TEXT_FIELDS.each do |page, (id, name, value)|
    test "#{page} saves a text field" do
      visit "/#{page}"
      assert_selector "#save-settings, #save-embed-settings", wait: 5
      select "SMTP", from: "email-mode" if page == "messages_email_settings"
      find("##{id}").set(value)
      save_and_check(page) { assert_equal value, Setting.get(name) }
      select "SMTP", from: "email-mode" if page == "messages_email_settings"
      assert_equal value, find("##{id}").value
    end
  end

  SWITCHES.each do |page, (id, name)|
    test "#{page} saves a switch" do
      visit "/#{page}"
      assert_selector "##{id}", wait: 5
      was = find("##{id}").checked?
      find("##{id}").click
      save_and_check(page) { assert_equal(was ? "0" : "1", Setting.get(name)) }
      assert_equal !was, find("##{id}").checked?
    end
  end

  test "theme settings saves a colour" do
    visit "/theme_settings"
    assert_selector "#company-color", wait: 5
    find("#company-color").set("#112233")
    save_and_check("theme_settings") { assert_equal "#112233", Setting.get("company_color") }
  end
end
