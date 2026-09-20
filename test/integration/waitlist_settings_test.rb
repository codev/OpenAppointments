require "test_helper"

# Business Settings: the Waiting List section with its switch and limits.
class WaitlistSettingsTest < ActionDispatch::IntegrationTest
  test "the section shows and saves the waitlist settings" do
    post "/login/validate", params: { username: "administrator", password: "administrator1" }
    get "/business_settings"
    assert_select "h5", text: I18n.t("ea.waitlist")
    assert_select "#waitlist-enabled[name='settings[waitlist_enabled]']"
    %w[waitlist_days waitlist_max_notices waitlist_min_slots waitlist_stagger_seconds].each do |name|
      assert_select "##{name.dasherize}[name='settings[#{name}]'][type=number]"
    end

    post "/business_settings/save", params: { settings: {
      waitlist_enabled: "1", waitlist_days: "21", waitlist_max_notices: "5", waitlist_min_slots: "2", waitlist_stagger_seconds: "90"
    } }
    assert_redirected_to "/business_settings"
    assert_equal %w[1 21 5 2 90], Setting.get_many(%w[waitlist_enabled waitlist_days waitlist_max_notices waitlist_min_slots waitlist_stagger_seconds]).values
  end
end
