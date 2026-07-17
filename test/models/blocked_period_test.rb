require "test_helper"

class BlockedPeriodTest < ActiveSupport::TestCase
  setup do
    @period = BlockedPeriod.create!(
      name: "Closed week",
      start_datetime: Time.new(2026, 8, 1, 0, 0, 0),
      end_datetime: Time.new(2026, 8, 8, 0, 0, 0)
    )
  end

  test "for_period finds date-level overlaps like EA" do
    assert_includes BlockedPeriod.for_period("2026-08-03", "2026-08-04"), @period
    assert_includes BlockedPeriod.for_period("2026-07-30", "2026-08-02"), @period
    assert_empty BlockedPeriod.for_period("2026-08-09", "2026-08-10")
  end

  test "EA quirk: entire_date_blocked? needs more than one covering period" do
    assert_not BlockedPeriod.entire_date_blocked?("2026-08-03")

    BlockedPeriod.create!(name: "Second", start_datetime: Time.new(2026, 8, 2, 0, 0, 0),
                          end_datetime: Time.new(2026, 8, 5, 0, 0, 0))
    assert BlockedPeriod.entire_date_blocked?("2026-08-03")
    assert_not BlockedPeriod.entire_date_blocked?("2026-08-07")
  end

  test "requires end after start" do
    period = BlockedPeriod.new(name: "Bad", start_datetime: Time.new(2026, 8, 2), end_datetime: Time.new(2026, 8, 1))
    assert_not period.valid?
  end
end
