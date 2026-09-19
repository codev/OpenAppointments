require "test_helper"

# The Timezone support switch: on (the default) shows timezone fields and uses
# each user's zone; off hides them and everyone runs on the default zone.
class TimezoneSupportTest < ActiveSupport::TestCase
  setup do
    Setting.set("default_timezone", "Europe/London")
    users(:zane).update!(timezone: "America/New_York")
  end

  test "on by default and when set to 1" do
    Setting.where(name: "timezone_support").delete_all
    Rails.cache.delete("setting/timezone_support")
    assert Setting.timezone_support?
    assert_equal "America/New_York", users(:zane).effective_timezone
    Setting.set("timezone_support", "1")
    assert Setting.timezone_support?
  end

  test "off hides zones and everyone uses the default" do
    Setting.set("timezone_support", "0")
    assert_not Setting.timezone_support?
    assert_equal "Europe/London", users(:zane).effective_timezone
    assert_equal "America/New_York", users(:zane).reload.timezone
  end

  test "the fixed_timezone setting is not consulted any more" do
    Setting.set("fixed_timezone", "1")
    Setting.set("timezone_support", "1")
    assert Setting.timezone_support?
    assert_equal "America/New_York", users(:zane).effective_timezone
  end
end
