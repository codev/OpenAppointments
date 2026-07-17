require "test_helper"

class BlockedPeriodTest < ActiveSupport::TestCase
  setup do
    @period = BlockedPeriod.create!(
      name: "Closed week",
      start_datetime: Time.new(2026, 8, 1, 0, 0, 0),
      end_datetime: Time.new(2026, 8, 8, 0, 0, 0)
    )
  end

  test "for_period finds overlaps" do
    assert_includes BlockedPeriod.for_period(Time.new(2026, 8, 3), Time.new(2026, 8, 4)), @period
    assert_empty BlockedPeriod.for_period(Time.new(2026, 8, 9), Time.new(2026, 8, 10))
  end

  test "entire_date_blocked?" do
    assert BlockedPeriod.entire_date_blocked?(Date.new(2026, 8, 3))
    assert_not BlockedPeriod.entire_date_blocked?(Date.new(2026, 8, 9))
  end

  test "requires end after start" do
    period = BlockedPeriod.new(name: "Bad", start_datetime: Time.new(2026, 8, 2), end_datetime: Time.new(2026, 8, 1))
    assert_not period.valid?
  end
end
