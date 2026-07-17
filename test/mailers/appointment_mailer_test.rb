require "test_helper"

class AppointmentMailerTest < ActionMailer::TestCase
  setup do
    @appointment = appointments(:upcoming)
    @service = services(:haircut)
    @provider = users(:jane)
    @customer = users(:james)
    @settings = { company_name: "Test Company", company_link: "https://example.org",
                  company_email: "info@example.org", company_color: nil,
                  date_format: "DMY", time_format: "regular" }
  end

  def saved_email(**overrides)
    AppointmentMailer.saved(
      **{ appointment: @appointment, service: @service, provider: @provider, customer: @customer,
          settings: @settings, recipient_email: @customer.email, recipient_language: "english",
          recipient_timezone: @customer.timezone, manage_mode: false,
          ics: IcsFile.stream(@appointment, @service, @provider, @customer),
          link_path: "/booking/reschedule/#{@appointment.booking_hash}",
          role: :customer }.merge(overrides)
    )
  end

  test "saved email recipient, subject and from" do
    email = saved_email
    assert_equal [ @customer.email ], email.to
    assert_equal I18n.t("ea.appointment_booked"), email.subject
    assert_equal "Test Company", email[:from].display_names.first
  end

  test "saved email attaches a parseable ICS file" do
    email = saved_email
    attachment = email.attachments["appointment.ics"]
    assert_not_nil attachment
    calendars = Icalendar::Calendar.parse(attachment.body.decoded)
    assert_equal 1, calendars.length
    assert_equal @service.name, calendars.first.events.first.summary
  end

  test "saved email body has service name and formatted time in recipient timezone" do
    body = saved_email.html_part.body.decoded
    assert_includes body, @service.name
    # 2026-07-20 10:00 Europe/London (provider) is 9:00 am UTC (recipient, DMY/regular).
    assert_includes body, "20/07/2026 9:00 am"
    assert_includes body, "20/07/2026 9:30 am"
  end

  test "deleted email has cancelled subject and includes the reason" do
    email = AppointmentMailer.deleted(
      appointment: @appointment, service: @service, provider: @provider, customer: @customer,
      settings: @settings, recipient_email: @customer.email, recipient_language: "english",
      recipient_timezone: @customer.timezone, reason: "Stylist unavailable"
    )
    assert_equal I18n.t("ea.appointment_cancelled_title"), email.subject
    body = email.html_part.body.decoded
    assert_includes body, I18n.t("ea.reason")
    assert_includes body, "Stylist unavailable"
  end

  test "deleted email omits the reason block when no reason given" do
    email = AppointmentMailer.deleted(
      appointment: @appointment, service: @service, provider: @provider, customer: @customer,
      settings: @settings, recipient_email: @customer.email, recipient_language: "english",
      recipient_timezone: @customer.timezone
    )
    assert_not_includes email.html_part.body.decoded, I18n.t("ea.reason")
  end
end
