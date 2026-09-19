require "test_helper"

class TimezoneSupportSettingsTest < ActionDispatch::IntegrationTest
  def login_admin
    post "/login/validate", params: { username: "administrator", password: "administrator1" }
  end

  test "the switch sits above the default timezone and saves" do
    login_admin
    get "/general_settings"
    assert_select "#timezone-support[name='settings[timezone_support]']"
    assert_select "#fixed-timezone", 0
    assert_operator response.body.index("timezone-support"), :<, response.body.index('id="default-timezone"')

    post "/general_settings/save", params: { settings: { default_timezone: "Europe/London", timezone_support: "0" } }
    assert_redirected_to "/general_settings"
    assert_equal "0", Setting.get("timezone_support")
    get "/general_settings"
    assert_select "#timezone-support:not([checked])"
  end

  test "the calendar script variables carry the switch" do
    login_admin
    Setting.set("timezone_support", "0")
    get "/calendar"
    assert_match(/"timezone_support":false/, response.body)
    assert_no_match(/fixed_timezone/, response.body)
  end

  test "the timezone support strings exist in every locale and the old ones are gone" do
    I18n.available_locales.each do |locale|
      %w[timezone_support timezone_support_hint].each do |key|
        assert I18n.t("ea.#{key}", locale: locale, fallback: false, default: nil).present?, "missing ea.#{key} in #{locale}"
      end
      assert_nil I18n.t("ea.fixed_timezone", locale: locale, fallback: false, default: nil), "stale ea.fixed_timezone in #{locale}"
    end
  end
end
