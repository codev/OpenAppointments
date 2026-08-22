require "test_helper"

class AppointmentStatusTest < ActiveSupport::TestCase
  test "special statuses can be renamed but not deleted" do
    cancelled = appointment_statuses(:cancelled)
    cancelled.update!(name: "Called off")
    assert_equal "Called off", Appointment.new(appointment_status: cancelled).status
    assert_not cancelled.destroy
    assert appointment_statuses(:confirmed).destroy
  end

  test "apply! renames, reorders, adds customs and keeps specials" do
    AppointmentStatus.apply!([
      { "id" => appointment_statuses(:booked).id, "name" => "Reserved", "kind" => "booked" },
      { "id" => "", "name" => "Waiting", "kind" => "custom" }
    ])
    assert_equal "Reserved", AppointmentStatus.of("booked").name
    assert_equal %w[Reserved Waiting], AppointmentStatus.names.first(2)
    assert_nil AppointmentStatus.find_by(name: "Confirmed")
    assert AppointmentStatus.of("late_cancel")
  end

  test "resolve creates unknown names as custom" do
    assert_equal "custom", AppointmentStatus.resolve("Maybe").kind
    assert_equal appointment_statuses(:booked), AppointmentStatus.resolve("Booked")
    assert_nil AppointmentStatus.resolve("")
  end

  test "cancelled appointments free their slot" do
    appointment = appointments(:upcoming)
    assert Appointment.provider_conflict?(appointment.id_users_provider, appointment.start_datetime, appointment.end_datetime)
    appointment.cancel!(kind: "late_cancel", reason: "Ill")
    assert_not Appointment.provider_conflict?(appointment.id_users_provider, appointment.start_datetime, appointment.end_datetime)
    assert_equal "Late Cancel", appointment.status
    assert appointment.frees_slot?
  end
end
