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
    assert_select "#settings-nav span", text: /Booking Settings/
    assert_select "#settings-nav a[href='/booking_settings']", count: 0
    assert_select "#settings-nav a[href='/general_settings']"

    get "/ldap_settings"
    assert_select "#settings-nav a.is-parent[href='/integrations']"

    get "/messages_twilio_settings"
    assert_select "#messages-nav a.is-parent[href='/messages_providers']"
  end

  test "turning timezone support off leaves stored zones alone and hides the controls" do
    login_admin
    users(:zane).update!(timezone: "America/New_York")
    post "/general_settings/save", params: { settings: { default_timezone: "Europe/London", timezone_support: "0" } }
    assert_redirected_to "/general_settings"
    assert_equal "America/New_York", users(:zane).reload.timezone
    assert_equal "Europe/London", users(:zane).effective_timezone

    get "/providers/new"
    assert_select "div.is-hidden label[for='provider_timezone']"
    get "/booking", params: { step: "time", service_id: services(:haircut).id, provider_id: users(:zane).id }
    assert_select "#select-timezone", 0
    assert_select "label[for='select-timezone']", 0
  end

  test "message failure report addresses default to the admins and must be valid" do
    login_admin
    get "/messages_settings"
    assert_match User.admins.first.email, response.body

    post "/messages_settings/save", params: { settings: { messages_failure_alert_emails: "a@example.org; not-an-email" } }
    assert_redirected_to "/messages_settings"
    follow_redirect!
    assert_select ".notice[data-tone=error]", text: /not-an-email/

    post "/messages_settings/save", params: { settings: { messages_failure_alert_emails: "a@example.org, b@example.org" } }
    assert_redirected_to "/messages_settings"
    assert_equal "a@example.org, b@example.org", Setting.get("messages_failure_alert_emails")
  end

  test "the notifications choice offers on, off and debug with the intercept fields tied to debug" do
    Setting.set("messages_enabled", "debug")
    Setting.set("messages_intercept_email", "dev@example.org")
    Setting.set("messages_intercept_phone", "+447700900123")
    login_admin
    get "/messages_settings"
    assert_select "select#messages-enabled[name='settings[messages_enabled]']" do
      assert_select "option[value='1']", text: "On"
      assert_select "option[value='0']", text: /^Off/
      assert_select "option[value='debug'][selected]", text: /^Debug/
    end
    assert_select "input[name='settings[messages_intercept_email]'][value='dev@example.org'][data-enabled-when='messages_enabled=debug']"
    assert_select "input[name='settings[messages_intercept_phone]'][value='+447700900123'][data-enabled-when='messages_enabled=debug']"
  end

  test "debug needs a valid intercept email and phone, and on or off clears them" do
    login_admin
    post "/messages_settings/save", params: { settings: { messages_enabled: "debug", messages_intercept_email: "not-an-email", messages_intercept_phone: "07700 900123" } }
    assert_redirected_to "/messages_settings"
    follow_redirect!
    assert_select ".notice[data-tone=error]", text: /Invalid email address/
    assert_equal "1", Setting.get("messages_enabled", "1")

    post "/messages_settings/save", params: { settings: { messages_enabled: "debug", messages_intercept_email: "dev@example.org", messages_intercept_phone: "12" } }
    follow_redirect!
    assert_select ".notice[data-tone=error]", text: /Invalid phone number/
    assert_equal "1", Setting.get("messages_enabled", "1")

    post "/messages_settings/save", params: { settings: { messages_enabled: "debug", messages_intercept_email: "", messages_intercept_phone: "" } }
    follow_redirect!
    assert_select ".notice[data-tone=error]", text: /Debug needs a valid email address and phone number/

    post "/messages_settings/save", params: { settings: { messages_enabled: "debug", messages_intercept_email: "dev@example.org", messages_intercept_phone: "07700 900123" } }
    assert_equal "debug", Setting.get("messages_enabled")
    assert_equal "dev@example.org", Setting.get("messages_intercept_email")
    assert_equal "+447700900123", Setting.get("messages_intercept_phone")

    post "/messages_settings/save", params: { settings: { messages_enabled: "0", messages_intercept_email: "dev@example.org", messages_intercept_phone: "07700 900123" } }
    assert_equal "0", Setting.get("messages_enabled")
    assert_equal "", Setting.get("messages_intercept_email").to_s
    assert_equal "", Setting.get("messages_intercept_phone").to_s
  end

  test "general settings save persists whitelisted settings" do
    login_admin
    post "/general_settings/save", params: { settings: { company_name: "Open Out", not_whitelisted: "ignored" } }
    assert_redirected_to "/general_settings"
    follow_redirect!
    assert_select ".notice[data-tone=success]", text: I18n.t("ea.settings_saved")
    assert_equal "Open Out", Setting.get("company_name")
    assert_nil Setting.get("not_whitelisted")
  end

  test "general settings save is forbidden without edit privilege" do
    login_provider
    post "/general_settings/save", params: { settings: { company_name: "X" } }
    assert_redirected_to "/general_settings"
    assert_equal "Test Company", Setting.get("company_name")

    post "/general_settings/save", params: { general_settings: [ { name: "company_name", value: "X" } ] }
    assert_response :internal_server_error
    assert_equal false, response.parsed_body["success"]
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

  test "the account form saves with a flash and refuses a taken username or mismatched passwords" do
    login_admin
    get "/account"
    assert_select "form#account-form[action='/account/save'] input[name='account[settings][username]'][value=administrator]"

    post "/account/save", params: { form: "1", account: { name: "Edson M", email: users(:admin).email, timezone: "UTC", language: "english",
                                                            settings: { username: "administrator", password: "", password_confirmation: "" } } }
    assert_redirected_to "/account"
    follow_redirect!
    assert_select ".notice[data-tone=success]", text: I18n.t("ea.settings_saved")
    assert_equal "Edson M", users(:admin).reload.name

    post "/account/save", params: { form: "1", account: { name: "Edson M", email: users(:admin).email,
                                                            settings: { username: "janedoe" } } }
    follow_redirect!
    assert_select ".notice[data-tone=error]", text: I18n.t("ea.username_already_exists")

    post "/account/save", params: { form: "1", account: { name: "Edson M", email: users(:admin).email,
                                                            settings: { username: "administrator", password: "password1", password_confirmation: "x" } } }
    follow_redirect!
    assert_select ".notice[data-tone=error]", text: I18n.t("ea.passwords_mismatch")
  end
  test "the terminology labels show their stored values and save from the form" do
    Setting.set("provider_label", "Stylist")
    Setting.set("provider_label_plural", "Stylists")
    login_admin
    get "/general_settings"
    assert_select "input#provider-label[name='settings[provider_label]'][value='Stylist']"
    assert_select "input#provider-label-plural[name='settings[provider_label_plural]'][value='Stylists']"
    assert_select "input#service-label[name='settings[service_label]']"

    post "/general_settings/save", params: { settings: { provider_label: "Barber", provider_label_plural: "Barbers",
                                                         service_label: "", service_label_plural: "" } }
    assert_redirected_to "/general_settings"
    assert_equal "Barber", Setting.get("provider_label")
    assert_equal "", Setting.get("service_label").to_s
  end
end

class LdapImportFormTest < ActionDispatch::IntegrationTest
  def login_admin
    post "/login/validate", params: { username: "administrator", password: "administrator1" }
  end

  test "the import dialog is a form creating the chosen role with its settings" do
    login_admin
    get "/ldap_settings"
    assert_select "form#ldap-import-form[action='/ldap_settings/import'] select[name=role_slug] option[value=provider]"

    post "/ldap_settings/import", params: { role_slug: "provider", user: { name: "Dir Provider", email: "dir@example.org", phone_number: "1", ldap_dn: "cn=dir" },
                                            settings: { username: "dirprovider", password: "password1" } }
    assert_redirected_to "/ldap_settings"
    follow_redirect!
    assert_select ".notice[data-tone=success]", text: I18n.t("ea.user_imported")
    provider = User.providers.find_by!(email: "dir@example.org")
    assert_equal "dirprovider", provider.settings.username
    assert_equal Setting.get("company_working_plan"), provider.settings.working_plan
    assert_equal "cn=dir", provider.ldap_dn

    post "/ldap_settings/import", params: { role_slug: "customer", user: { name: "Dir Customer", email: "dirc@example.org", phone_number: "2", ldap_dn: "cn=c" } }
    assert User.customers.exists?(email: "dirc@example.org")

    post "/ldap_settings/import", params: { role_slug: "admin", user: { name: "No pass", email: "np@example.org", phone_number: "3", ldap_dn: "cn=n" }, settings: { username: "np" } }
    follow_redirect!
    assert_select ".notice[data-tone=error]", text: /password/
  end
end

class DriveStringsTest < ActionDispatch::IntegrationTest
  test "the unsaved changes and custom status strings exist in every locale" do
    I18n.available_locales.each do |locale|
      %w[unsaved_changes_prompt leave_page status_custom].each do |key|
        assert I18n.t("ea.#{key}", locale: locale, fallback: false, default: nil).present?, "missing ea.#{key} in #{locale}"
      end
    end
  end
end
