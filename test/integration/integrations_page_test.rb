require "test_helper"

class IntegrationsPageTest < ActionDispatch::IntegrationTest
  def login_admin
    post "/login/validate", params: { username: "administrator", password: "administrator1" }
    assert_equal({ "success" => true }, response.parsed_body)
  end

  test "every integration card carries a status line" do
    login_admin
    get "/integrations"
    assert_response :success
    assert_select ".integration-status", count: 10
  end

  test "statuses reflect the settings with a tick when active" do
    login_admin
    get "/integrations"
    assert_select ".integration-status", text: /\p{So}/, count: 0

    Setting.set("altcha_enabled", "1")
    Setting.set("captcha_provider", "altcha")
    Setting.set("altcha_hmac_key", "k")
    Setting.set("ldap_is_active", "1")
    Setting.set("google_analytics_code", "G-1234")
    Webhook.create!(name: "hook", url: "https://example.org/h", actions: "appointment_save")
    Webhook.create!(name: "hook2", url: "https://example.org/h2", actions: "appointment_save")

    get "/integrations"
    assert_select ".integration-status", text: /\p{So}/, count: 4
    assert_select ".integration-status", text: /2 #{I18n.t('ea.webhooks')}/
    assert_select ".integration-status", text: /^#{I18n.t('ea.not_active')}$/, count: 6
  end

  test "captcha counts as active with only the login switch on" do
    login_admin
    Setting.set("captcha_login_enabled", "1")
    Setting.set("captcha_provider", "altcha")
    Setting.set("altcha_hmac_key", "k")
    get "/integrations"
    assert_select ".integration-status", text: /\p{So}.*#{I18n.t('ea.active')}/, count: 1
  end

  test "not_active exists in every locale" do
    I18n.available_locales.each do |locale|
      assert I18n.t("ea.not_active", locale: locale, fallback: false, default: nil).present?,
             "missing ea.not_active in #{locale}"
    end
  end
end
