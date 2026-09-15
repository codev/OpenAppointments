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
end
