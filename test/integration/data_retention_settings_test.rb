require "test_helper"

# Data retention lives on General Settings, not on Legal Contents.
class DataRetentionSettingsTest < ActionDispatch::IntegrationTest
  def login_admin
    post "/login/validate", params: { username: "administrator", password: "administrator1" }
  end

  test "the retention days field is on general settings and saves from there" do
    login_admin
    get "/general_settings"
    assert_select "#data-retention-days[name='settings[data_retention_days]']"
    assert_select "h5", text: I18n.t("ea.data_retention")

    post "/general_settings/save", params: { settings: { data_retention_days: "400" } }
    assert_redirected_to "/general_settings"
    assert_equal "400", Setting.get("data_retention_days")
  end

  test "legal contents no longer carries the retention field" do
    login_admin
    get "/legal_settings"
    assert_select "#data-retention-days", 0
    assert_select "h5", text: I18n.t("ea.data_retention"), count: 0
  end
end
