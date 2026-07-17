require "test_helper"

class CalendarPullTest < ActiveSupport::TestCase
  # Minimal stand-ins for google-api event objects.
  EventDT = Struct.new(:date_time)
  FakeEvent = Struct.new(:id, :status, :summary, :start, :end)

  class FakeGateway
    def initialize(events) = @events = events
    def sync_events(_provider, _calendar_id, _from, _to) = @events
  end

  setup do
    @provider = users(:jane)
    @provider.settings.update!(google_sync: true, google_calendar: "primary",
                               sync_past_days: 30, sync_future_days: 90)
  end

  test "imports an external google event as an unavailability" do
    event = FakeEvent.new("ext-1", "confirmed", "Dentist",
                          EventDT.new("2026-07-25T09:00:00+01:00"), EventDT.new("2026-07-25T10:00:00+01:00"))
    pull = CalendarPull.new(gateway: FakeGateway.new([ event ]))

    assert_difference "Appointment.unavailabilities.count", 1 do
      counts = pull.sync_provider(@provider)
      assert_equal 1, counts[:imported]
    end
    imported = Appointment.find_by(id_google_calendar: "ext-1")
    assert imported.is_unavailability
    assert_equal "2026-07-25 09:00:00", imported.start_datetime.strftime("%Y-%m-%d %H:%M:%S")
    assert_equal "Dentist", imported.notes
  end

  test "converts event instants to the provider timezone before storing" do
    # 08:00 UTC in July is 09:00 wall-clock for a Europe/London provider.
    event = FakeEvent.new("ext-utc", "confirmed", "Remote",
                          EventDT.new("2026-07-25T08:00:00Z"), EventDT.new("2026-07-25T09:00:00Z"))
    pull = CalendarPull.new(gateway: FakeGateway.new([ event ]))

    pull.sync_provider(@provider)
    imported = Appointment.find_by(id_google_calendar: "ext-utc")
    assert_equal "2026-07-25 09:00:00", imported.start_datetime.strftime("%Y-%m-%d %H:%M:%S")
    assert_equal "2026-07-25 10:00:00", imported.end_datetime.strftime("%Y-%m-%d %H:%M:%S")
  end

  test "does not re-import an already synced event" do
    @provider.provider_appointments.create!(is_unavailability: true, id_google_calendar: "ext-2",
                                            start_datetime: "2026-07-25 09:00:00", end_datetime: "2026-07-25 10:00:00")
    event = FakeEvent.new("ext-2", "confirmed", "Existing",
                          EventDT.new("2026-07-25T09:00:00+01:00"), EventDT.new("2026-07-25T10:00:00+01:00"))
    pull = CalendarPull.new(gateway: FakeGateway.new([ event ]))

    assert_no_difference "Appointment.count" do
      assert_equal 0, pull.sync_provider(@provider)[:imported]
    end
  end

  test "removes a local record whose remote event was cancelled" do
    owned = @provider.provider_appointments.create!(customer: users(:james), service: services(:haircut),
                                                    start_datetime: "2026-07-25 11:00:00",
                                                    end_datetime: "2026-07-25 11:30:00", id_google_calendar: "own-1")
    event = FakeEvent.new("own-1", "cancelled", nil, nil, nil)
    pull = CalendarPull.new(gateway: FakeGateway.new([ event ]))

    assert_difference "Appointment.count", -1 do
      assert_equal 1, pull.sync_provider(@provider)[:removed]
    end
    assert_nil Appointment.find_by(id: owned.id)
  end
end
