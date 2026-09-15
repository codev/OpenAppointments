require "application_system_test_case"

# Picking an hour brings the Next button into view, as picking a service or
# provider does.
class BookingScrollTest < ApplicationSystemTestCase
  test "choosing an hour scrolls the time step down to Next" do
    page.driver.browser.manage.window.resize_to(1000, 450)
    visit root_url
    select services(:haircut).name, from: "select-service"
    find("#button-next-1").click
    select users(:zane).name, from: "select-provider"
    find("#button-next-2").click
    assert_selector "#wizard-frame-3", visible: :visible, wait: 5
    assert_selector "#available-hours .available-hour", minimum: 1, wait: 10
    sleep 0.5 # the provider step's own scroll animation finishes
    page.execute_script("window.scrollTo(0, 0)")
    assert_not next_in_view?, "Next should start below the fold"

    # The driver scrolls the hour into view before clicking; only the step's
    # own scroll brings Next up from below the hours list.
    first("#available-hours .available-hour").click
    assert 20.times.any? { next_in_view? || (sleep(0.1) && false) }, "Next did not come into view"
    assert_selector "#available-hours .selected-hour"
  end

  def next_in_view?
    page.evaluate_script("document.getElementById('button-next-3').getBoundingClientRect().bottom <= window.innerHeight")
  end
end
