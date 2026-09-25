require "test_helper"

# The booking and late cancellation windows are independent: a late window
# longer than the booking window is allowed.
class BusinessSettingsWindowsTest < ActionDispatch::IntegrationTest
  test "a zero hour booking window saves with a six hour late cancellation window" do
    post "/login/validate", params: { username: "administrator", password: "administrator1" }
    post "/business_settings/save", params: {
      settings: { future_booking_limit: "30" },
      minutes: { book_advance_timeout: { hours: "0", minutes: "0" },
                 late_cancellation_timeout: { hours: "6", minutes: "0" } }
    }
    assert_redirected_to "/business_settings"
    assert_nil flash[:alert]
    assert_equal "0", Setting.get("book_advance_timeout")
    assert_equal "360", Setting.get("late_cancellation_timeout")
  end

  test "the late window hint does not tie it to the booking window" do
    post "/login/validate", params: { username: "administrator", password: "administrator1" }
    get "/business_settings"
    assert_response :success
    assert_includes response.body, "keeps the slot free for others"
    assert_not_includes response.body, "longer than the booking window"
  end

  test "the future booking limit can be as short as one day" do
    post "/login/validate", params: { username: "administrator", password: "administrator1" }
    get "/business_settings"
    assert_select "input[name='settings[future_booking_limit]'][min='1']"
  end

  test "the release time sits under the future booking limit, saves, and refuses a malformed time" do
    post "/login/validate", params: { username: "administrator", password: "administrator1" }
    get "/business_settings"
    assert_select "select[name='settings[booking_release_time]'] option[selected][value='00:00']"
    assert_select "select[name='settings[booking_release_time]'] option[value='12:00']"
    assert_match I18n.t("ea.booking_release_time_hint"), response.body
    limit_at = response.body.index("settings[future_booking_limit]")
    release_at = response.body.index("settings[booking_release_time]")
    assert limit_at < release_at, "release time follows the future booking limit"

    post "/business_settings/save", params: { settings: { booking_release_time: "12:00" } }
    assert_equal "12:00", Setting.get("booking_release_time")

    post "/business_settings/save", params: { settings: { booking_release_time: "25:00" } }
    assert flash[:alert].present?
    assert_equal "12:00", Setting.get("booking_release_time")
  end
end
