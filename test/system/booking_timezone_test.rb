require "application_system_test_case"

# Without timezone support, the time step shows the stylist's wall-clock hours
# whatever zone the visitor's browser is in.
class BookingTimezoneTest < ApplicationSystemTestCase
  test "timezone support off labels hours in the stylist's zone for a browser abroad" do
    Setting.set("timezone_support", "0")
    Setting.set("default_timezone", "Europe/London")
    page.driver.browser.execute_cdp("Emulation.setTimezoneOverride", timezoneId: "America/New_York")
    visit root_url
    select services(:haircut).name, from: "select-service"
    find("#button-next-1").click
    select users(:zane).name, from: "select-provider"
    find("#button-next-2").click
    assert_selector "#available-hours .available-hour", minimum: 1, wait: 10
    assert_no_selector "#select-timezone", visible: :all
    first_hour = first("#available-hours .available-hour")
    assert_equal "09:00", first_hour["data-value"]
    assert_equal "9:00 am", first_hour.text
  end
end
