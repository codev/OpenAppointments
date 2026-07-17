require "test_helper"

class AppointmentTest < ActiveSupport::TestCase
  test "generates a 12-char booking hash on create" do
    appointment = Appointment.create!(
      start_datetime: Time.new(2026, 7, 21, 10, 0, 0),
      end_datetime: Time.new(2026, 7, 21, 10, 30, 0),
      provider: users(:jane), customer: users(:james), service: services(:haircut)
    )
    assert_match(/\A[A-Za-z0-9]{12}\z/, appointment.booking_hash)
  end

  test "keeps an explicitly assigned hash" do
    assert_equal "abc123def456", appointments(:upcoming).booking_hash
  end

  test "requires customer and service unless unavailability" do
    appointment = Appointment.new(
      start_datetime: Time.new(2026, 7, 21, 10, 0, 0),
      end_datetime: Time.new(2026, 7, 21, 10, 30, 0),
      provider: users(:jane)
    )
    assert_not appointment.valid?
    assert appointment.errors[:id_users_customer].any?
    assert appointment.errors[:id_services].any?

    appointment.is_unavailability = true
    assert appointment.valid?
  end

  test "rejects events shorter than EA minimum duration" do
    appointment = Appointment.new(
      start_datetime: Time.new(2026, 7, 21, 10, 0, 0),
      end_datetime: Time.new(2026, 7, 21, 10, 4, 0),
      provider: users(:jane), is_unavailability: true
    )
    assert_not appointment.valid?
  end

  test "rejects end before start" do
    appointment = Appointment.new(
      start_datetime: Time.new(2026, 7, 21, 10, 0, 0),
      end_datetime: Time.new(2026, 7, 21, 9, 0, 0),
      provider: users(:jane), is_unavailability: true
    )
    assert_not appointment.valid?
  end

  test "datetimes round-trip as wall-clock without timezone shifting" do
    appointment = appointments(:upcoming)
    appointment.reload
    assert_equal "2026-07-20 10:00:00", appointment.start_datetime.strftime("%Y-%m-%d %H:%M:%S")
  end

  test "overlapping scope matches EA conflict semantics" do
    overlap = Appointment.overlapping(Time.new(2026, 7, 20, 10, 15, 0), Time.new(2026, 7, 20, 10, 45, 0))
    assert_includes overlap, appointments(:upcoming)

    adjacent = Appointment.overlapping(Time.new(2026, 7, 20, 10, 30, 0), Time.new(2026, 7, 20, 11, 0, 0))
    assert_not_includes adjacent, appointments(:upcoming)
  end

  test "scopes split appointments and unavailabilities" do
    assert_includes Appointment.appointments, appointments(:upcoming)
    assert_not_includes Appointment.appointments, appointments(:lunch_block)
    assert_includes Appointment.unavailabilities, appointments(:lunch_block)
  end

  test "cascade: deleting customer removes their appointments" do
    assert_difference "Appointment.count", -1 do
      users(:james).destroy
    end
  end
end
