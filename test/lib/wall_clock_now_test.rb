require "test_helper"

# Stored times are wall clock in the default zone; the server clock is UTC.
class WallClockNowTest < ActiveSupport::TestCase
  test "wall_clock_now is the default zone's clock as a plain time" do
    Setting.set("default_timezone", "Europe/London")
    saved = ENV["TZ"]
    ENV["TZ"] = "UTC"
    travel_to Time.utc(2026, 8, 1, 12, 5) do
      now = BookingWindows.wall_clock_now
      assert_equal "2026-08-01 13:05", now.strftime("%Y-%m-%d %H:%M")
      assert_instance_of Time, now
    end
  ensure
    saved.nil? ? ENV.delete("TZ") : ENV["TZ"] = saved
  end
end
