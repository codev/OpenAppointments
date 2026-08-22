require "test_helper"

class AppointmentSeriesTest < ActiveSupport::TestCase
  TODAY = Date.new(2026, 7, 20) # a Monday; fixture provider zane works Mon, Tue, Thu, Fri 09:00-18:00

  def build_series(repeat, starts_on: TODAY, start_time: "10:00")
    AppointmentSeries.create!(
      provider: users(:zane), customer: users(:jx), service: services(:haircut),
      ice_schedule: AppointmentSeries.schedule_from(repeat, starts_on),
      starts_on: starts_on, start_time: start_time, duration: 30, status: "Booked",
      ends_on: repeat["ends"] == "on" ? Date.parse(repeat["ends_on"]) : nil
    )
  end

  setup do
    Setting.set("future_booking_limit", "60")
    Appointment.delete_all
  end

  test "weekly occurrences are created up to the booking limit" do
    series = build_series({ "frequency" => "weekly", "interval" => 1, "weekdays" => [ 1 ], "ends" => "never" })
    result = series.materialise(now: TODAY)

    assert_equal 9, result[:created].size, "Mondays from 20 Jul to 18 Sep"
    assert_empty result[:skipped]
    first = series.appointments.order(:start_datetime).first
    assert_equal Time.new(2026, 7, 20, 10, 0), first.start_datetime
    assert_equal TODAY, first.occurrence_at
    assert_equal series.id, first.series_id
  end

  test "materialising again adds nothing and respects an end date and count" do
    series = build_series({ "frequency" => "weekly", "interval" => 1, "weekdays" => [ 1 ], "ends" => "after", "count" => 3 })
    series.materialise(now: TODAY)
    assert_equal 3, series.appointments.count
    assert_empty series.materialise(now: TODAY)[:created]

    ended = build_series({ "frequency" => "daily", "interval" => 1, "ends" => "on", "ends_on" => "2026-07-21" },
                         start_time: "11:00")
    assert_equal [ Date.new(2026, 7, 20), Date.new(2026, 7, 21) ], ended.materialise(now: TODAY)[:created]
  end

  test "clashing dates are skipped with a reason and recorded" do
    Appointment.create!(provider: users(:zane), customer: users(:jx), service: services(:haircut),
                        start_datetime: Time.new(2026, 7, 27, 10, 0), end_datetime: Time.new(2026, 7, 27, 10, 30))
    WorkingPlanException.create!(provider: users(:zane), start_date: Date.new(2026, 8, 3), end_date: Date.new(2026, 8, 3))
    BlockedPeriod.create!(name: "Closed", start_datetime: Time.new(2026, 8, 10, 0, 0), end_datetime: Time.new(2026, 8, 10, 23, 59))

    series = build_series({ "frequency" => "weekly", "interval" => 1, "weekdays" => [ 1 ], "ends" => "never" })
    result = series.materialise(now: TODAY)

    assert_equal [ [ "2026-07-27", "busy" ], [ "2026-08-03", "not_working" ], [ "2026-08-10", "blocked" ] ],
                 result[:skipped].map { |entry| [ entry["date"], entry["reason"] ] }
    assert_equal 6, result[:created].size
    assert_equal 3, series.reload.skipped_list.size
  end

  test "a day the provider does not work is not booked" do
    series = build_series({ "frequency" => "weekly", "interval" => 1, "weekdays" => [ 3 ], "ends" => "never" }) # Wednesday
    result = series.materialise(now: TODAY)
    assert_empty result[:created]
    assert result[:skipped].all? { |entry| entry["reason"] == "not_working" }
  end

  test "cancel_from removes later occurrences and ends the series" do
    series = build_series({ "frequency" => "weekly", "interval" => 1, "weekdays" => [ 1 ], "ends" => "never" })
    series.materialise(now: TODAY)
    deleted = series.cancel_from(Date.new(2026, 8, 3))

    assert_equal 7, deleted.size
    assert_equal 2, series.appointments.count
    assert_equal Date.new(2026, 8, 2), series.reload.ends_on
    assert_empty series.future_dates(Date.new(2026, 8, 3))
  end

  test "reschedule! replaces future occurrences with the new pattern" do
    series = build_series({ "frequency" => "weekly", "interval" => 1, "weekdays" => [ 1 ], "ends" => "never" })
    series.materialise(now: TODAY)
    result = series.reschedule!({ "frequency" => "weekly", "interval" => 2, "weekdays" => [ 2 ], "ends" => "never" },
                                now: Date.new(2026, 7, 28))

    assert_equal 2, series.appointments.where("occurrence_at < ?", Date.new(2026, 7, 28)).count, "past kept"
    assert result[:created].all?(&:tuesday?)
    assert_equal result[:created].size, series.appointments.where("occurrence_at >= ?", Date.new(2026, 7, 28)).count
  end

  test "description is readable" do
    series = build_series({ "frequency" => "weekly", "interval" => 1, "weekdays" => [ 1 ], "ends" => "never" })
    assert_match(/Weekly on Mondays/, series.description)
  end
end
