require "test_helper"

class FixedTimezoneTest < ActiveSupport::TestCase
  setup do
    Setting.set("default_timezone", "Europe/London")
  end

  test "effective_timezone is the stored one unless fixed" do
    user = users(:zane)
    user.update!(timezone: "America/New_York")
    assert_equal "America/New_York", user.effective_timezone

    Setting.set("fixed_timezone", "1")
    assert_equal "Europe/London", user.effective_timezone
    assert_equal "Europe/London", EaRows.provider_row(user)["timezone"]
  end

  test "saving a user while fixed stores the default timezone" do
    Setting.set("fixed_timezone", "1")
    user = users(:zane)
    user.update!(timezone: "America/New_York")
    assert_equal "Europe/London", user.reload.timezone
  end
end
