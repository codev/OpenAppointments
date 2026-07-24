require "test_helper"

# Confirmation page actions: company website button, Google Calendar, ics download,
# and the ics attachment on the customer confirmation email.
class BookingConfirmationTest < ActionDispatch::IntegrationTest
  test "the confirmation page links the company website and calendar actions" do
    Setting.set("company_name", "Test Company")
    Setting.set("company_link", "https://example.org/salon")

    get "/booking_confirmation/of/#{appointments(:upcoming).booking_hash}"
    assert_response :success

    assert_select "#go-to-company[href='https://example.org/salon']", text: /Go to Test Company/
    assert_select "#go-to-company i", false
    assert_select "#add-to-google-calendar"
    assert_select "#download-ics[href=?]", "/booking_confirmation/ics/#{appointments(:upcoming).booking_hash}"
    assert_no_match I18n.t("ea.go_to_booking_page"), css_select("#go-to-company").first.text
  end

  test "the ics endpoint streams the appointment calendar" do
    get "/booking_confirmation/ics/#{appointments(:upcoming).booking_hash}"
    assert_response :success
    assert_equal "text/calendar", response.media_type
    assert_match "BEGIN:VCALENDAR", response.body
    assert_match appointments(:upcoming).service.name, response.body

    get "/booking_confirmation/ics/nonsense"
    assert_redirected_to "/"
  end

  test "the customer confirmation email carries the ics attachment" do
    notification = Notification.create!(title: "Confirmation", event: "created",
                                        audiences: [ "customer" ], channels: [ "email" ])
    message = Message.create!(direction: "outgoing", channel: "email", audience: "customer",
                              to_address: "someone@example.org", subject: "Booked", body: "See you soon",
                              appointment_id: appointments(:upcoming).id, notification_id: notification.id)

    mail = MessagesMailer.outgoing(message)
    attachment = mail.attachments["appointment.ics"]
    assert attachment, "expected an appointment.ics attachment"
    assert_match "BEGIN:VCALENDAR", attachment.body.decoded
  end
end
