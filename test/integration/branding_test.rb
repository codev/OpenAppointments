require "test_helper"

class BrandingTest < ActionDispatch::IntegrationTest
  test "booking page is branded OpenAppointments" do
    get "/"
    assert_response :success
    assert_match "OpenAppointments", response.body
    assert_no_match(/Easy!Appointments/, response.body)
  end

  test "login page carries no old brand" do
    get "/login"
    assert_response :success
    assert_no_match(/Easy!Appointments/, response.body)
  end

  test "about page shows the new name" do
    post "/login/validate", params: { username: "administrator", password: "administrator1" }
    get "/about"
    assert_response :success
    assert_match "OpenAppointments", response.body
    assert_no_match(/Easy!Appointments/, response.body)
  end

  test "no locale contains the old brand name" do
    I18n.available_locales.each do |locale|
      payload = I18n.t("ea", locale: locale, default: {}).values.grep(String).join(" ")
      assert_no_match(/Easy!Appointments/, payload, "old brand present in locale #{locale}")
    end
  end

  test "appointment mail is branded OpenAppointments" do
    appointment = appointments(:upcoming)
    settings = { company_name: "Test Company", company_link: "https://example.org",
                 company_email: "info@example.org", company_color: nil,
                 date_format: "DMY", time_format: "regular" }
    mail = AppointmentMailer.saved(
      appointment: appointment, service: appointment.service, provider: appointment.provider,
      customer: appointment.customer, settings: settings,
      recipient_email: appointment.customer.email, recipient_language: "english",
      recipient_timezone: "UTC", manage_mode: false,
      ics: IcsFile.stream(appointment, appointment.service, appointment.provider, appointment.customer),
      link_path: "/booking/reschedule/#{appointment.booking_hash}", role: :customer
    )
    body = mail.html_part.body.decoded
    assert_no_match(/Easy!Appointments/, body)
    assert_match "OpenAppointments", body
  end
end
