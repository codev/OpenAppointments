require "test_helper"

class ProviderDayTest < ActiveSupport::TestCase
  MONDAY = Date.new(2026, 7, 20)

  def day_for(provider, appointments: [], unavailabilities: [], blocked: [])
    ProviderDay.new(provider, MONDAY, appointments: appointments, unavailabilities: unavailabilities, blocked_periods: blocked)
  end

  # Stored datetimes are wall-clock Time values in the process zone; the free
  # gaps and blocked periods must be built the same way, whatever Time.zone is,
  # or the entries sort by the wrong instants.
  test "entries keep time order when Time.zone differs from the process zone" do
    users(:zane).settings.update!(working_plan: { monday: { start: "11:30", end: "21:00", breaks: [] } }.to_json)
    appointment = Appointment.create!(provider: users(:zane), customer: users(:jx), service: services(:haircut),
                                      start_datetime: "2026-07-20 15:00:00", end_datetime: "2026-07-20 15:30:00", status: "Booked")
    blocked = BlockedPeriod.create!(name: "Fair", start_datetime: "2026-07-19 08:00:00", end_datetime: "2026-07-20 10:00:00")
    lunch = appointments(:lunch_block) # 12:00 to 13:00

    Time.use_zone("Asia/Tokyo") do
      entries = day_for(users(:zane), appointments: [ appointment ], unavailabilities: [ lunch ], blocked: [ blocked ]).entries
      assert_equal %w[blocked free unavailability free appointment free], entries.map(&:kind)
      assert_equal [ "00:00", "11:30", "12:00", "13:00", "15:00", "15:30" ], entries.map { |entry| entry.start.strftime("%H:%M") }
      assert_equal [ "10:00", "12:00", "13:00", "15:00", "15:30", "21:00" ], entries.map { |entry| entry.end.strftime("%H:%M") }
      assert_equal entries[1].start.utc_offset, appointment.start_datetime.utc_offset
    end
  end

  test "breaks in the working plan show as break entries, not as free time" do
    entries = day_for(users(:zane)).entries # fixture plan: 09:00 to 18:00 with a 14:30 to 15:00 break
    break_entry = entries.find { |entry| entry.kind == "break" }
    assert_equal [ "14:30", "15:00", I18n.t("ea.break") ], [ break_entry.start.strftime("%H:%M"), break_entry.end.strftime("%H:%M"), break_entry.title ]
    assert entries.none? { |entry| entry.kind == "free" && entry.start.strftime("%H:%M") < "15:00" && entry.end.strftime("%H:%M") > "14:30" }
  end
end
