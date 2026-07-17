require "test_helper"

# Table-driven port tests for Availability::Engine. 2026-07-20 is a Monday.
# Fixtures: jane (Europe/London) works Mon 09:00-18:00 with a 14:30-15:00 break and has
# a 10:00-10:30 appointment (haircut) plus a 12:00-13:00 unavailability that day.
class AvailabilityEngineTest < ActiveSupport::TestCase
  DATE = "2026-07-20".freeze

  setup do
    @jane = users(:jane)
    @haircut = services(:haircut)       # 30 min, interval 15, 1 attendant
    @group = services(:group_session)   # 60 min, interval 30, 3 attendants
    # A "now" far before the test date so advance timeout removes nothing.
    @early_now = Time.new(2026, 7, 1, 12, 0, 0)
    @engine = Availability::Engine.new(now: @early_now)
  end

  def expected_monday_hours
    %w[09:00 09:15 09:30
       10:30 10:45 11:00 11:15 11:30
       13:00 13:15 13:30 13:45 14:00
       15:00 15:15 15:30 15:45 16:00 16:15 16:30 16:45 17:00 17:15 17:30]
  end

  test "monday hours subtract break, appointment and unavailability" do
    assert_equal expected_monday_hours, @engine.available_hours(DATE, @haircut, @jane)
  end

  test "day off (null weekday plan) yields no hours" do
    assert_empty @engine.available_hours("2026-07-22", @haircut, @jane) # Wednesday: null
  end

  test "EA quirk: weekday plan without breaks key yields no periods" do
    plan = JSON.parse(@jane.settings.working_plan)
    plan["monday"] = { "start" => "09:00", "end" => "18:00" } # no breaks key
    @jane.settings.update!(working_plan: plan.to_json)
    assert_empty @engine.available_hours(DATE, @haircut, @jane)
  end

  test "working plan exception overrides weekday hours" do
    WorkingPlanException.create!(provider: @jane, start_date: "2026-07-20", end_date: "2026-07-20",
                                 start_time: "10:00", end_time: "12:00", breaks: "[]")
    # Exception window 10:00-12:00 minus the 10:00-10:30 appointment; 11:30 is the last
    # slot that fits 30 minutes before 12:00. The 12:00-13:00 unavailability is outside.
    assert_equal %w[10:30 10:45 11:00 11:15 11:30], @engine.available_hours(DATE, @haircut, @jane)
  end

  test "working plan exception day off wins over weekday plan" do
    WorkingPlanException.create!(provider: @jane, start_date: "2026-07-20", end_date: "2026-07-21",
                                 start_time: nil, end_time: nil)
    assert_empty @engine.available_hours(DATE, @haircut, @jane)
  end

  test "exception with breaks splits the window" do
    WorkingPlanException.create!(provider: @jane, start_date: "2026-07-20", end_date: "2026-07-20",
                                 start_time: "09:00", end_time: "11:00",
                                 breaks: '[{"start":"09:30","end":"10:30"}]')
    # 09:00-09:30 cannot fit 30 min... it can exactly: remaining 30 >= 30 -> 09:00 only.
    # 10:30-11:00 blocked by the 10:00-10:30 appointment? No: appointment ends 10:30, so
    # 10:30-11:00 remains and fits exactly one 30-min slot.
    assert_equal %w[09:00 10:30], @engine.available_hours(DATE, @haircut, @jane)
  end

  test "single blocked period subtracts hours but does not block the whole date" do
    BlockedPeriod.create!(name: "Morning block", start_datetime: Time.new(2026, 7, 20, 9, 0, 0),
                          end_datetime: Time.new(2026, 7, 20, 12, 0, 0))
    hours = @engine.available_hours(DATE, @haircut, @jane)
    assert_equal %w[13:00 13:15 13:30 13:45 14:00
                    15:00 15:15 15:30 15:45 16:00 16:15 16:30 16:45 17:00 17:15 17:30], hours
  end

  test "EA quirk: two covering blocked periods block the entire date" do
    2.times do |i|
      BlockedPeriod.create!(name: "Block #{i}", start_datetime: Time.new(2026, 7, 19, 0, 0, 0),
                            end_datetime: Time.new(2026, 7, 21, 23, 0, 0))
    end
    assert_empty @engine.available_hours(DATE, @haircut, @jane)
  end

  test "book advance timeout drops hours at or before the threshold" do
    zone = Time.find_zone!("Europe/London")
    engine = Availability::Engine.new(now: zone.parse("#{DATE} 09:00"))
    hours = engine.available_hours(DATE, @haircut, @jane)
    # Threshold is 09:30 (30-min setting): 09:00/09:15/09:30 dropped, 09:45 not offered
    # anyway (next slot after 09:30 in the free period is 09:45? period 09:00-10:00 yields
    # 09:00/09:15/09:30 only), so morning slots vanish entirely.
    assert_equal expected_monday_hours - %w[09:00 09:15 09:30], hours
  end

  test "future booking limit boundary day yields no hours (strictly greater passes)" do
    engine = Availability::Engine.new(now: Time.new(2026, 7, 1, 0, 0, 0))
    # 2026-09-29 == now + 90 days exactly: threshold == selected midnight -> [].
    assert_empty engine.send(:consider_future_booking_limit, "2026-09-29", [ "ok" ])
    assert_equal [ "ok" ], engine.send(:consider_future_booking_limit, "2026-09-28", [ "ok" ])
    assert_empty engine.send(:consider_future_booking_limit, "2026-09-30", [ "ok" ])
  end

  test "reschedule exclusion frees the appointment slot" do
    hours = @engine.available_hours(DATE, @haircut, @jane,
                                    exclude_appointment_id: appointments(:upcoming).id)
    assert_includes hours, "10:00"
    assert_includes hours, "09:45"
  end

  test "slot interval stepping follows the service" do
    @haircut.update!(slot_interval: 60)
    hours = @engine.available_hours(DATE, @haircut, @jane)
    assert_equal %w[09:00 10:30 11:30 13:00 14:00 15:00 16:00 17:00], hours
  end

  test "multi attendant service allows overlapping bookings up to capacity" do
    2.times do
      Appointment.create!(provider: @jane, customer: users(:james), service: @group,
                          start_datetime: Time.new(2026, 7, 20, 15, 0, 0),
                          end_datetime: Time.new(2026, 7, 20, 16, 0, 0))
    end
    hours = @engine.available_hours(DATE, @group, @jane)
    assert_includes hours, "15:00" # 2 of 3 attendants booked

    Appointment.create!(provider: @jane, customer: users(:james), service: @group,
                        start_datetime: Time.new(2026, 7, 20, 15, 0, 0),
                        end_datetime: Time.new(2026, 7, 20, 16, 0, 0))
    hours = @engine.available_hours(DATE, @group, @jane)
    assert_not_includes hours, "15:00" # capacity reached
    assert_not_includes hours, "15:30" # overlapping slot is also at capacity
  end

  test "multi attendant slots skip other-service occupancy" do
    # The 10:00-10:30 haircut appointment overlaps group slots starting 09:30/10:00.
    hours = @engine.available_hours(DATE, @group, @jane)
    assert_not_includes hours, "10:00"
    assert_not_includes hours, "09:30"
    assert_includes hours, "10:30"
  end

  test "invalid date format raises" do
    assert_raises(ArgumentError) { @engine.available_periods("2026/07/20", @jane) }
  end
end
