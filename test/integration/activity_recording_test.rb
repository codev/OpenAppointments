require "test_helper"

# Every door that books, changes, cancels or deletes an appointment leaves a
# line in the activity log, naming who did it.
class ActivityRecordingTest < ActionDispatch::IntegrationTest
  DATE = "2026-07-20".freeze

  def login_admin
    post "/login/validate", params: { username: "administrator", password: "administrator1" }
  end

  def register_params(start:)
    { post_data: {
      appointment: { "start_datetime" => start, "id_services" => services(:haircut).id,
                     "id_users_provider" => users(:zane).id },
      customer: { "name" => "New Customer", "email" => "new@example.org",
                  "phone_number" => "+447700900123", "timezone" => "Europe/London" },
      manage_mode: false
    } }
  end

  def admin_appointment_data(id: nil, status: "Booked", start: "#{DATE} 14:00:00", finish: "#{DATE} 14:30:00")
    { id: id, id_services: services(:haircut).id, id_users_provider: users(:zane).id,
      id_users_customer: users(:jx).id, start_datetime: start, end_datetime: finish,
      status: status, notes: "", location: "", color: "#7cbae8", is_unavailability: 0 }.compact
  end

  test "a booking from the public page is recorded as booked by the booking page" do
    travel_to Time.new(2026, 7, 10, 12, 0, 0) do
      post "/booking/register", params: register_params(start: "#{DATE} 09:00:00")
    end
    assert_response :success
    assert response.parsed_body["appointment_id"], response.body
    event = ActivityEvent.newest_first.first
    assert_equal "appointment_booked", event.kind
    assert_equal Activity::BOOKING_PAGE, event.actor
    assert_equal response.parsed_body["appointment_id"], event.appointment_id
    assert_match "New Customer", event.summary
    assert_match "Zane", event.summary
  end

  test "an admin save is recorded as booked with the admin's name, a later save as changed" do
    login_admin
    post "/calendar/save_appointment", params: { appointment_data: admin_appointment_data, notify_users: 0 }
    assert_equal true, response.parsed_body["success"]
    booked = ActivityEvent.newest_first.first
    assert_equal "appointment_booked", booked.kind
    assert_equal "Edson Mori (Administrator)", booked.actor

    post "/calendar/save_appointment", params: {
      appointment_data: admin_appointment_data(id: booked.appointment_id, start: "#{DATE} 15:00:00", finish: "#{DATE} 15:30:00"),
      notify_users: 0
    }
    changed = ActivityEvent.newest_first.first
    assert_equal "appointment_changed", changed.kind
    assert_equal booked.appointment_id, changed.appointment_id
  end

  test "admin cancel and delete are recorded" do
    login_admin
    appointment = appointments(:upcoming)
    post "/calendar/cancel_appointment", params: { appointment_id: appointment.id, notify_users: 0, cancellation_reason: "Ill" }
    assert_equal true, response.parsed_body["success"]
    cancelled = ActivityEvent.newest_first.first
    assert_equal "appointment_cancelled", cancelled.kind
    assert_match "Ill", cancelled.details

    other = Appointment.create!(provider: users(:zane), customer: users(:jx), service: services(:haircut),
                                start_datetime: Time.new(2026, 7, 27, 10, 0), end_datetime: Time.new(2026, 7, 27, 10, 30))
    post "/calendar/delete_appointment", params: { appointment_id: other.id, notify_users: 0 }
    assert_equal "appointment_deleted", ActivityEvent.newest_first.first.kind
  end

  test "a customer cancelling from the link is recorded as cancelled by the booking page" do
    appointment = appointments(:upcoming)
    travel_to Time.new(2026, 7, 10, 12, 0, 0) do
      post "/booking_cancellation/of/#{appointment.booking_hash}", params: { cancellation_reason: "Away" }
    end
    event = ActivityEvent.where(appointment_id: appointment.id).newest_first.first
    assert_equal "appointment_cancelled", event.kind
    assert_equal Activity::BOOKING_PAGE, event.actor
    assert_match "Away", event.details
  end

  test "an unavailability saved from the calendar is recorded" do
    login_admin
    post "/calendar/save_unavailability", params: { unavailability: {
      id_users_provider: users(:zane).id, start_datetime: "#{DATE} 16:00:00", end_datetime: "#{DATE} 17:00:00", notes: "Dentist"
    } }
    assert_equal true, response.parsed_body["success"]
    assert_equal "unavailability_saved", ActivityEvent.newest_first.first.kind
  end
end
