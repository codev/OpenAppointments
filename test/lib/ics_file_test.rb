require "test_helper"

# The event location is the appointment's own location, else the service
# location, else the company address.
class IcsFileTest < ActiveSupport::TestCase
  def location_line(appointment)
    ics = IcsFile.stream(appointment, appointment.service, appointment.provider, appointment.customer)
    ics.gsub(/\r\n[ \t]/, "")[/^LOCATION:([^\r\n]*)/, 1]&.gsub("\\,", ",")
  end

  setup do
    @appointment = appointments(:upcoming)
    Setting.set("company_address", "1 High Street, London")
  end

  test "the appointment location comes first" do
    @appointment.update!(location: "Pop-up shop")
    @appointment.service.update!(location: "Salon")

    assert_equal "Pop-up shop", location_line(@appointment)
  end

  test "the service location is used when the appointment has none" do
    @appointment.update!(location: "")
    @appointment.service.update!(location: "Salon")

    assert_equal "Salon", location_line(@appointment)
  end

  test "the company address is used when neither has a location" do
    @appointment.update!(location: "")
    @appointment.service.update!(location: "")

    assert_equal "1 High Street, London", location_line(@appointment)
  end

  test "there is no location line when nothing is set" do
    Setting.set("company_address", "")
    @appointment.update!(location: "")
    @appointment.service.update!(location: "")

    assert_nil location_line(@appointment)
  end

  test "the summary is the company, service and stylist" do
    Setting.set("company_name", "Open Out")
    ics = unfolded(@appointment)

    assert_equal "Open Out: #{@appointment.service.name} with #{@appointment.provider.name}",
                 ics[/^SUMMARY:([^\r\n]*)/, 1]
  end

  test "there are no attendees and no contact details" do
    ics = unfolded(@appointment)

    assert_no_match(/^ATTENDEE/, ics)
    assert_no_match(/#{Regexp.escape(@appointment.provider.email)}/, ics)
    assert_no_match(/#{Regexp.escape(@appointment.customer.email)}/, ics)
  end

  test "the description keeps the names, notes and meeting link" do
    @appointment.update!(notes: "Bring a photo", meeting_link: "https://meet.example.org/abc")
    ics = unfolded(@appointment)

    assert_match @appointment.provider.name, ics
    assert_match @appointment.customer.name, ics
    assert_match "Bring a photo", ics
    assert_match "https://meet.example.org/abc", ics
  end

  test "both alarms remain" do
    assert_equal 2, unfolded(@appointment).scan("BEGIN:VALARM").size
  end

  def unfolded(appointment)
    IcsFile.stream(appointment, appointment.service, appointment.provider, appointment.customer)
           .gsub(/\r\n[ \t]/, "")
  end
end
