require "test_helper"

class BookingWindowTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  # The preloaded window must equal the per-date engine results.
  test "the window matches a fresh engine per date and loads each table once" do
    BlockedPeriod.create!(name: "Fair", start_datetime: "2026-07-14 00:00:00", end_datetime: "2026-07-14 23:59:00")
    WorkingPlanException.create!(id_users_provider: users(:zane).id, start_date: "2026-07-21", end_date: "2026-07-21",
                                 start_time: "13:00", end_time: "16:00", breaks: "[]")
    Setting.set("future_booking_limit", "30")

    travel_to Time.new(2026, 7, 10, 12, 0, 0) do
      per_date = {}
      (Date.current..Date.current + 30.days).each do |date|
        hours = Availability::Engine.new.available_hours(date.to_s, services(:haircut), users(:zane))
        per_date[date.to_s] = hours if hours.any?
      end

      queries = 0
      subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") { queries += 1 }
      window = BookingWindow.build(services(:haircut), users(:zane).id)
      ActiveSupport::Notifications.unsubscribe(subscriber)

      assert_equal per_date, window
      assert_not window.key?("2026-07-14")
      assert_equal "13:00", window["2026-07-21"].first
      assert_operator queries, :<, 15, "the window must not query per day"
    end
  end

  test "a reschedule excludes its own appointment and any provider merges the hours" do
    travel_to Time.new(2026, 7, 10, 12, 0, 0) do
      assert_not_includes BookingWindow.build(services(:haircut), users(:zane).id)["2026-07-20"], "10:00"
      assert_includes BookingWindow.build(services(:haircut), users(:zane).id,
                                          exclude_appointment_id: appointments(:upcoming).id)["2026-07-20"], "10:00"
      assert_includes BookingWindow.build(services(:haircut), "any-provider")["2026-07-20"], "09:00"
    end
  end
end
