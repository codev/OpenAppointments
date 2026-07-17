require "test_helper"

class CalendarTest < ActionDispatch::IntegrationTest
  def login_admin
    post "/login/validate", params: { username: "administrator", password: "administrator1" }
    assert_equal({ "success" => true }, response.parsed_body)
  end

  def login_provider
    post "/login/validate", params: { username: "janedoe", password: "janedoe1" }
    assert_equal({ "success" => true }, response.parsed_body)
  end

  test "calendar page requires session then renders" do
    get "/calendar"
    assert_redirected_to "/login"

    login_admin
    get "/calendar"
    assert_response :success
    assert_match "window.vars", response.body
  end

  test "get_calendar_appointments with provider filter returns EA shape" do
    login_admin
    post "/calendar/get_calendar_appointments", params: {
      record_id: users(:jane).id, filter_type: "provider",
      start_date: "2026-07-19", end_date: "2026-07-21"
    }
    assert_response :success
    body = response.parsed_body
    assert_equal 1, body["appointments"].length
    appointment = body["appointments"].first
    assert_equal "2026-07-20 10:00:00", appointment["start_datetime"]
    assert_equal "abc123def456", appointment["hash"]
    assert_equal "Jane Doe", appointment["provider"]["name"]
    assert_equal "Trim Cut", appointment["service"]["name"]
    assert_equal "James Doe", appointment["customer"]["name"]
    assert appointment["provider"]["settings"].key?("working_plan")
    assert_not appointment["provider"]["settings"].key?("password")
    assert_equal 1, body["unavailabilities"].length
    assert_equal true, body["unavailabilities"].first["is_unavailability"]
    assert body.key?("blocked_periods")
  end

  test "get_calendar_appointments service filter excludes unavailabilities" do
    login_admin
    post "/calendar/get_calendar_appointments", params: {
      record_id: services(:haircut).id, filter_type: "service",
      start_date: "2026-07-19", end_date: "2026-07-21"
    }
    body = response.parsed_body
    assert_equal 1, body["appointments"].length
    assert_empty body["unavailabilities"]
  end

  test "get_calendar_appointments without filter type returns empty sets" do
    login_admin
    post "/calendar/get_calendar_appointments", params: {
      record_id: "5", start_date: "2026-07-19", end_date: "2026-07-21"
    }
    assert_equal({ "appointments" => [], "unavailabilities" => [] }, response.parsed_body)
  end

  test "table view returns appointments unavailabilities and blocked periods" do
    login_admin
    post "/calendar/get_calendar_appointments_for_table_view", params: {
      start_date: "2026-07-19", end_date: "2026-07-21"
    }
    body = response.parsed_body
    assert_equal 1, body["appointments"].length
    assert_equal 1, body["unavailabilities"].length
  end

  test "save_appointment creates appointment with new customer" do
    login_admin
    assert_difference [ "Appointment.appointments.count", "User.customers.count" ], 1 do
      post "/calendar/save_appointment", params: {
        customer_data: { name: "Cal Endar", email: "cal@example.org",
                         phone_number: "+447700900999" },
        appointment_data: { start_datetime: "2026-07-21 09:00:00", end_datetime: "2026-07-21 09:30:00",
                            id_users_provider: users(:jane).id, id_services: services(:haircut).id,
                            status: "Booked" }
      }
    end
    assert_equal({ "success" => true }, response.parsed_body)
  end

  test "save_appointment reports conflicts unless forced" do
    login_admin
    conflicting = { start_datetime: "2026-07-20 10:15:00", end_datetime: "2026-07-20 10:45:00",
                    id_users_provider: users(:jane).id, id_services: services(:haircut).id,
                    id_users_customer: users(:james).id }

    post "/calendar/save_appointment", params: { appointment_data: conflicting }
    body = response.parsed_body
    assert_equal false, body["success"]
    assert_equal true, body["conflict"]

    assert_difference "Appointment.appointments.count", 1 do
      post "/calendar/save_appointment", params: { appointment_data: conflicting, force_save: true }
    end
    assert_equal({ "success" => true }, response.parsed_body)
  end

  test "delete_appointment destroys the appointment" do
    login_admin
    assert_difference "Appointment.appointments.count", -1 do
      post "/calendar/delete_appointment", params: {
        appointment_id: appointments(:upcoming).id, cancellation_reason: "test"
      }
    end
    assert_equal({ "success" => true }, response.parsed_body)
  end

  test "unavailability save and delete round trip" do
    login_admin
    post "/calendar/save_unavailability", params: {
      unavailability: { start_datetime: "2026-07-21 12:00:00", end_datetime: "2026-07-21 13:00:00",
                        id_users_provider: users(:jane).id, notes: "Lunch" }
    }
    assert_equal true, response.parsed_body["success"]

    record = Appointment.unavailabilities.order(:id).last
    assert_equal "Lunch", record.notes

    post "/calendar/delete_unavailability", params: { unavailability_id: record.id }
    assert_equal({ "success" => true }, response.parsed_body)
    assert_nil Appointment.find_by(id: record.id)
  end

  test "working plan exception save requires users edit privilege" do
    login_provider
    post "/calendar/save_working_plan_exception", params: {
      provider_id: users(:jane).id,
      working_plan_exception: { startDate: "2026-07-25", endDate: "2026-07-25",
                                startTime: "10:00", endTime: "14:00", breaks: [] }
    }
    assert_equal false, response.parsed_body["success"]

    login_admin
    assert_difference "WorkingPlanException.count", 1 do
      post "/calendar/save_working_plan_exception", params: {
        provider_id: users(:jane).id,
        working_plan_exception: { startDate: "2026-07-25", endDate: "2026-07-25",
                                  startTime: "10:00", endTime: "14:00", breaks: [] }
      }
    end
    body = response.parsed_body
    assert_equal true, body["success"]

    post "/calendar/delete_working_plan_exception", params: { exception_id: body["id"], provider_id: users(:jane).id }
    assert_equal({ "success" => true }, response.parsed_body)
  end

  test "provider cannot manage another providers events" do
    login_provider
    post "/calendar/save_unavailability", params: {
      unavailability: { start_datetime: "2026-07-21 12:00:00", end_datetime: "2026-07-21 13:00:00",
                        id_users_provider: 999_999 }
    }
    assert_response :forbidden
  end

  test "provider sees only own events in calendar feeds" do
    login_provider
    post "/calendar/get_calendar_appointments", params: {
      record_id: "all", start_date: "2026-07-19", end_date: "2026-07-21"
    }
    body = response.parsed_body
    assert body["appointments"].all? { |a| a["id_users_provider"] == users(:jane).id }
  end
end
