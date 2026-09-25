require "test_helper"

# The far end of public booking: today + Future Booking Limit days on the
# business clock, where the newest day opens at the release time.
class BookingReleaseTimeTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  setup do
    Setting.set("default_timezone", "Europe/London")
    Setting.set("future_booking_limit", "7")
  end

  def london(*parts) = Time.find_zone!("Europe/London").local(*parts)

  test "before the release time the window ends a day earlier; at it the next day opens" do
    Setting.set("booking_release_time", "12:00")
    assert_equal Date.new(2026, 10, 11), BookingWindows.last_bookable_date(london(2026, 10, 5, 11, 59))
    assert_equal Date.new(2026, 10, 12), BookingWindows.last_bookable_date(london(2026, 10, 5, 12, 0))
  end

  test "release 00:00, the default, gives today plus the limit all day" do
    assert_equal Date.new(2026, 10, 12), BookingWindows.last_bookable_date(london(2026, 10, 5, 0, 0, 0))
    assert_equal Date.new(2026, 10, 12), BookingWindows.last_bookable_date(london(2026, 10, 5, 23, 59))
  end

  test "an invalid stored release time counts as 00:00" do
    Setting.set("booking_release_time", "noon")
    assert_equal Date.new(2026, 10, 12), BookingWindows.last_bookable_date(london(2026, 10, 5, 0, 30))
  end

  test "the booking window and the engine end on the same day" do
    Setting.set("booking_release_time", "12:00")
    travel_to london(2026, 10, 5, 11, 59) do # a Monday; zane works Mondays
      assert_not BookingWindow.build(services(:haircut), users(:zane).id).key?("2026-10-12")
      assert_empty Availability::Engine.new.available_hours("2026-10-12", services(:haircut), users(:zane))
    end
    travel_to london(2026, 10, 5, 12, 0) do
      assert BookingWindow.build(services(:haircut), users(:zane).id).key?("2026-10-12")
      assert_not_empty Availability::Engine.new.available_hours("2026-10-12", services(:haircut), users(:zane))
    end
  end

  test "just after midnight in summer the far day is already open (no 01:00 drift)" do
    Setting.set("future_booking_limit", "5")
    travel_to london(2026, 7, 1, 0, 30) do # 30 June 23:30 UTC
      assert BookingWindow.build(services(:haircut), users(:zane).id).key?("2026-07-06")
    end
  end

  test "the window starts on the business day, so a business west of UTC keeps today in the evening" do
    Setting.set("default_timezone", "America/Los_Angeles")
    users(:zane).update!(timezone: "America/Los_Angeles")
    Setting.set("book_advance_timeout", "0") # 17:15 and 17:30 stay bookable
    travel_to Time.find_zone!("America/Los_Angeles").local(2026, 10, 5, 17, 0) do # Monday, 00:00 UTC Tuesday
      assert BookingWindow.build(services(:haircut), users(:zane).id).key?("2026-10-05")
    end
  end
end
