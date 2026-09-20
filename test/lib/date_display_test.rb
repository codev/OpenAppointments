require "test_helper"

# Date display: how dates are written on pages and in messages. The style
# adds day and month names in the reader's language; the order follows the
# date format setting. Date fields keep the numeric format.
class DateDisplayTest < ActiveSupport::TestCase
  MONDAY = Date.new(2026, 7, 20)

  test "the styles in day month year order" do
    Setting.set("date_format", "DMY")
    assert_equal "20/07/2026", DateDisplay.format(MONDAY, style: "numeric")
    assert_equal "20 Jul 2026", DateDisplay.format(MONDAY, style: "month_short")
    assert_equal "20 July 2026", DateDisplay.format(MONDAY, style: "month_long")
    assert_equal "Mon 20 Jul 2026", DateDisplay.format(MONDAY, style: "day_short")
    assert_equal "Monday 20 July 2026", DateDisplay.format(MONDAY, style: "day_long")
  end

  test "month first and year first orders" do
    Setting.set("date_format", "MDY")
    assert_equal "Mon, Jul 20, 2026", DateDisplay.format(MONDAY, style: "day_short")
    assert_equal "Monday, July 20, 2026", DateDisplay.format(MONDAY, style: "day_long")
    Setting.set("date_format", "YMD")
    assert_equal "2026 Jul 20, Mon", DateDisplay.format(MONDAY, style: "day_short")
    assert_equal "2026/07/20", DateDisplay.format(MONDAY, style: "numeric")
  end

  test "the setting picks the style and an unknown style is numeric" do
    Setting.set("date_format", "DMY")
    Setting.set("date_display", "day_long")
    assert_equal "Monday 20 July 2026", DateDisplay.format(MONDAY)
    Setting.set("date_display", "nonsense")
    assert_equal "20/07/2026", DateDisplay.format(MONDAY)
  end

  test "names come from the reader's language, falling back to English" do
    Setting.set("date_format", "DMY")
    I18n.with_locale(:fr) { assert_equal "lundi 20 juillet 2026", DateDisplay.format(MONDAY, style: "day_long") }
    I18n.with_locale(:de) { assert_equal "Mo 20 Jul 2026", DateDisplay.format(MONDAY, style: "day_short") }
    I18n.with_locale(:bu) { assert_equal "Monday 20 July 2026", DateDisplay.format(MONDAY, style: "day_long") }
  end

  test "times are appended with the time format and the message token uses the display style" do
    Setting.set("date_format", "DMY")
    Setting.set("date_display", "day_short")
    Setting.set("time_format", "military")
    assert_equal "Mon 20 Jul 2026 14:30", DateDisplay.format_time(Time.new(2026, 7, 20, 14, 30, 0))
    assert_equal "Mon 20 Jul 2026", Messaging::Template.format_date(Time.new(2026, 7, 20, 14, 30, 0))
  end
end
