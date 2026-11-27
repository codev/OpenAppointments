require "application_system_test_case"

# Printing List and Free gives a black and white day list: no header, filters
# or buttons, the dates, stylists and entries alone.
class PrintTest < ApplicationSystemTestCase
  def print_media(on)
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", media: on ? "print" : "")
  end

  teardown { print_media(false) }

  def background_of(selector)
    page.evaluate_script("getComputedStyle(document.querySelector(#{selector.to_json})).backgroundColor")
  end

  test "the Free page prints its title, dates and free slots without the chrome" do
    Setting.set("future_booking_limit", "4")
    login_as_admin
    travel_to Time.new(2026, 7, 19, 12, 0, 0) do
      visit free_url
      assert_selector ".day-entry-free", wait: 5
      assert_no_selector ".print-title", visible: :visible
      print_media(true)
      assert_selector ".print-title", text: "Free for appointments", visible: :visible
      assert_no_selector "#header", visible: :visible
      assert_no_selector "#footer", visible: :visible
      assert_no_selector "#day-filter", visible: :visible
      assert_no_selector "#free-range", visible: :visible
      assert_selector ".date-column h5", text: "20/07/2026", visible: :visible
      assert_selector ".provider-column h6", text: "Zane", visible: :visible
      assert_selector ".day-entry-free", visible: :visible
      assert_equal "rgba(0, 0, 0, 0)", background_of(".day-entry-free")
    end
  end

  test "the List page prints the day's entries without the toolbar" do
    Appointment.create!(provider: users(:zane), customer: users(:jx), service: services(:haircut),
                        start_datetime: "2026-07-20 10:00:00", end_datetime: "2026-07-20 10:30:00")
    login_as_admin
    visit appointments_url(date: "2026-07-20")
    assert_selector ".day-entry-appointment", wait: 5
    print_media(true)
    assert_no_selector "#header", visible: :visible
    assert_no_selector "#day-filter", visible: :visible
    assert_no_selector "#select-date", visible: :visible
    assert_no_selector "#today", visible: :visible
    assert_selector ".date-column h5", text: "20/07/2026", visible: :visible
    assert_selector ".day-entry-appointment", visible: :visible
    assert_equal "rgba(0, 0, 0, 0)", background_of(".day-entry-appointment")
  end
end
