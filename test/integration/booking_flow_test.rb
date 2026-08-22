require "test_helper"

# End-to-end booking contract tests against the EA JSON shapes the ported JS expects.
class BookingFlowTest < ActionDispatch::IntegrationTest
  DATE = "2026-07-20".freeze # Monday, see availability engine tests

  test "booking page renders the wizard" do
    get "/"
    assert_response :success
    assert_match "book-appointment-wizard", response.body
    assert_match "wizard-frame-1", response.body
    assert_match "window.vars", response.body
  end

  test "old mobile browsers are not rejected with 406" do
    get "/", headers: { "User-Agent" => "Mozilla/5.0 (Android 9; Mobile; rv:68.0) Gecko/68.0 Firefox/68.0" }
    assert_response :success
  end

  test "get_available_hours returns EA hour strings" do
    travel_to Time.new(2026, 7, 1, 12, 0, 0) do
      post "/booking/get_available_hours", params: {
        service_id: services(:haircut).id, provider_id: users(:zane).id,
        selected_date: DATE, service_duration: 30, manage_mode: 0, appointment_id: ""
      }
    end
    assert_response :success
    hours = response.parsed_body
    assert_includes hours, "09:00"
    assert_not_includes hours, "10:00" # taken by fixture appointment
    assert_not_includes hours, "14:30" # break
  end

  test "get_available_hours with any-provider merges providers" do
    travel_to Time.new(2026, 7, 1, 12, 0, 0) do
      post "/booking/get_available_hours", params: {
        service_id: services(:haircut).id, provider_id: "any-provider",
        selected_date: DATE, manage_mode: 0
      }
    end
    assert_includes response.parsed_body, "09:00"
  end

  test "get_available_hours empty provider returns empty array" do
    post "/booking/get_available_hours", params: { service_id: services(:haircut).id, selected_date: DATE }
    assert_equal [], response.parsed_body
  end

  test "get_unavailable_dates marks past and dayoff dates" do
    travel_to Time.new(2026, 7, 10, 12, 0, 0) do
      get "/booking/get_unavailable_dates", params: {
        provider_id: users(:zane).id, service_id: services(:haircut).id,
        selected_date: DATE, manage_mode: 0
      }
    end
    assert_response :success
    dates = response.parsed_body
    assert_includes dates, "2026-07-01" # past
    assert_includes dates, "2026-07-22" # Wednesday: day off
    assert_not_includes dates, "2026-07-20"
  end

  test "register books an appointment and returns the hash" do
    travel_to Time.new(2026, 7, 10, 12, 0, 0) do
      assert_difference [ "Appointment.count", "User.customers.count" ], 1 do
        post "/booking/register", params: register_params(start: "#{DATE} 09:00:00")
      end
    end
    assert_response :success
    body = response.parsed_body
    appointment = Appointment.find(body["appointment_id"])
    assert_equal appointment.booking_hash, body["appointment_hash"]
    assert_equal "2026-07-20 09:30:00", appointment.end_datetime.strftime("%Y-%m-%d %H:%M:%S")
    assert_equal "Booked", appointment.status
    assert_equal services(:haircut).color, appointment.color
    customer = appointment.customer
    assert_equal "New Customer", customer.name
    assert_equal "english", customer.language
  end

  test "register rejects an unavailable hour with EA error shape" do
    travel_to Time.new(2026, 7, 10, 12, 0, 0) do
      assert_no_difference "Appointment.count" do
        post "/booking/register", params: register_params(start: "#{DATE} 10:00:00") # taken
      end
    end
    body = response.parsed_body
    assert_equal false, body["success"]
    assert_match(/not available/i, body["message"]) # EA: requested_hour_is_unavailable
  end

  test "register reuses existing customer by email" do
    travel_to Time.new(2026, 7, 10, 12, 0, 0) do
      assert_no_difference "User.customers.count" do
        post "/booking/register", params: register_params(start: "#{DATE} 09:00:00",
                                                          email: users(:jx).email)
      end
    end
    assert_equal users(:jx).id, Appointment.order(:id).last.id_users_customer
  end

  test "register blocks a customer already booked in a containing slot" do
    travel_to Time.new(2026, 7, 10, 12, 0, 0) do
      post "/booking/register", params: register_params(start: "#{DATE} 10:00:00",
                                                        email: users(:jx).email)
    end
    body = response.parsed_body
    assert_equal false, body["success"]
  end

  test "register with any-provider picks a provider" do
    travel_to Time.new(2026, 7, 10, 12, 0, 0) do
      post "/booking/register", params: register_params(start: "#{DATE} 09:00:00", provider: "any-provider")
    end
    assert_response :success
    assert_equal users(:zane).id, Appointment.order(:id).last.id_users_provider
  end

  test "consents are recorded when legal documents are displayed" do
    Setting.set("display_privacy_policy", "1")
    Setting.set("display_terms_and_conditions", "1")
    travel_to Time.new(2026, 7, 10, 12, 0, 0) do
      assert_difference "Consent.count", 2 do
        post "/booking/register", params: register_params(start: "#{DATE} 09:00:00")
      end
    end
    assert_equal %w[privacy-policy terms-and-conditions], Consent.order(:type).last(2).map(&:type)
  end

  test "disable_booking forbids booking endpoints and shows message page" do
    Setting.set("disable_booking", "1")

    get "/"
    assert_response :success
    assert_match(/not accepting new appointments/, response.body)

    post "/booking/register", params: register_params(start: "#{DATE} 09:00:00")
    assert_response :forbidden

    post "/booking/get_available_hours", params: { service_id: services(:haircut).id }
    assert_response :forbidden
  end

  test "reschedule books a new appointment and marks the original rescheduled" do
    appointment = appointments(:upcoming)
    travel_to Time.new(2026, 7, 10, 12, 0, 0) do
      assert_difference "Appointment.count", 1 do
        post "/booking/register", params: register_params(
          start: "#{DATE} 11:00:00", email: users(:jx).email,
          extra_appointment: { "id" => appointment.id }, manage_mode: true
        )
      end
    end
    assert_response :success
    replacement = Appointment.find(response.parsed_body["appointment_id"])
    assert_equal "2026-07-20 11:00:00", replacement.start_datetime.strftime("%Y-%m-%d %H:%M:%S")
    assert_equal "Booked", replacement.status
    assert_equal "Rescheduled", appointment.reload.status
    assert_equal replacement, appointment.rescheduled_to
    assert_equal "2026-07-20 10:00:00", appointment.start_datetime.strftime("%Y-%m-%d %H:%M:%S")
  end

  test "reschedule page enters manage mode, late window shows late cancel only" do
    travel_to Time.new(2026, 7, 10, 12, 0, 0) do
      get "/booking/reschedule/#{appointments(:upcoming).booking_hash}"
      assert_response :success
      assert_match '"manage_mode":true', response.body # window.vars JSON is emitted raw
    end

    travel_to provider_zone.parse("2026-07-20 09:45") do
      get "/booking/reschedule/#{appointments(:upcoming).booking_hash}"
      assert_response :success
      assert_no_match '"manage_mode":true', response.body
      assert_includes response.body, "/booking_cancellation/late/#{appointments(:upcoming).booking_hash}"
    end

    appointments(:upcoming).cancel!
    get "/booking/reschedule/#{appointments(:upcoming).booking_hash}"
    assert_match(/not found/i, response.body)

    get "/booking/reschedule/unknownhash00"
    assert_response :success
    assert_match(/not found/i, response.body)
  end

  test "register refuses a reschedule inside the late window or of a cancelled appointment" do
    appointment = appointments(:upcoming)
    travel_to provider_zone.parse("2026-07-20 09:45") do
      assert_no_difference "Appointment.count" do
        post "/booking/register", params: register_params(
          start: "2026-07-21 11:00:00", email: users(:jx).email,
          extra_appointment: { "id" => appointment.id }, manage_mode: true
        )
      end
    end
    assert_equal false, response.parsed_body["success"]
    assert_equal "Booked", appointment.reload.status
  end

  test "late window uses the provider timezone" do
    users(:zane).update!(timezone: "Europe/London")
    Setting.set("book_advance_timeout", "60")
    Setting.set("late_cancellation_timeout", "60")
    appointment = appointments(:upcoming) # 10:00 provider local time
    zone = Time.find_zone!(users(:zane).effective_timezone)
    assert_not BookingWindows.late?(appointment, zone.parse("2026-07-20 08:59"))
    assert BookingWindows.late?(appointment, zone.parse("2026-07-20 09:01"))
  end

  test "customer cancel keeps the row as cancelled; inside the late window as late cancel" do
    appointment = appointments(:upcoming)
    travel_to Time.new(2026, 7, 10, 12, 0, 0) do
      assert_no_difference "Appointment.count" do
        post "/booking_cancellation/of/#{appointment.booking_hash}", params: { cancellation_reason: "Away" }
      end
    end
    assert_response :success
    assert_equal "Cancelled", appointment.reload.status
    assert_includes appointment.notes, "Away"
    assert_not Appointment.provider_conflict?(appointment.id_users_provider, appointment.start_datetime,
                                              appointment.end_datetime)

    appointment.update!(appointment_status: nil)
    travel_to provider_zone.parse("2026-07-20 09:45") do
      post "/booking_cancellation/late/#{appointment.booking_hash}", params: { cancellation_reason: "Ill" }
    end
    assert_response :success
    assert_equal "Late Cancel", appointment.reload.status
  end

  private

  # Inside the late window of the 10:00 fixture appointment, in the provider's
  # zone (CI runs in UTC, the fixture provider is in Europe/London).
  def provider_zone = Time.find_zone!(users(:zane).effective_timezone)

  def register_params(start:, provider: users(:zane).id, email: "new@example.org",
                      extra_appointment: {}, manage_mode: false)
    {
      post_data: {
        appointment: {
          "start_datetime" => start,
          "id_services" => services(:haircut).id,
          "id_users_provider" => provider
        }.merge(extra_appointment),
        customer: {
          "name" => "New Customer", "email" => email,
          "phone_number" => "+447700900123", "timezone" => "Europe/London"
        },
        manage_mode: manage_mode
      }
    }
  end
end
