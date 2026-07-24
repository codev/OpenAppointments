require "test_helper"

class WorkingPlanExceptionTest < ActiveSupport::TestCase
  test "covering scope matches date range inclusively" do
    exception = WorkingPlanException.create!(
      start_date: Date.new(2026, 7, 21), end_date: Date.new(2026, 7, 23),
      start_time: "10:00", end_time: "14:00", provider: users(:zane)
    )
    assert_includes WorkingPlanException.covering(Date.new(2026, 7, 21)), exception
    assert_includes WorkingPlanException.covering(Date.new(2026, 7, 23)), exception
    assert_empty WorkingPlanException.covering(Date.new(2026, 7, 24))
  end

  test "day_off? when times blank" do
    exception = WorkingPlanException.new(start_date: Date.today, end_date: Date.today)
    assert exception.day_off?
    exception.start_time = "09:00"
    exception.end_time = "17:00"
    assert_not exception.day_off?
  end

  test "break_list parses JSON breaks" do
    exception = WorkingPlanException.new(breaks: '[{"start":"12:00","end":"12:30"}]')
    assert_equal [ { "start" => "12:00", "end" => "12:30" } ], exception.break_list
    assert_equal [], WorkingPlanException.new.break_list
  end
end
