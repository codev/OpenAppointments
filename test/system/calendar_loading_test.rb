require "application_system_test_case"

# The Calendar fetches its events once per view, the saved filter included,
# and a Drive visit away tears it down so coming back renders one calendar.
class CalendarLoadingTest < ApplicationSystemTestCase
  COUNT_REQUESTS = "performance.getEntriesByType('resource').filter((e) => e.name.includes('get_calendar_appointments')).length"

  def wait_for_requests(count)
    assert page.has_css?("#calendar .fc-view-harness", wait: 10)
    50.times do
      return if page.evaluate_script(COUNT_REQUESTS) >= count

      sleep 0.2
    end
  end

  test "the saved filter is loaded with a single request" do
    login_as_admin
    saved = { providers: [], services: [ services(:group_session).id ] }.to_json
    page.execute_script("window.localStorage.setItem('OpenAppointments.CalendarFilter', arguments[0])", saved)
    visit "/calendar"
    wait_for_requests(1)
    sleep 1
    assert_equal 1, page.evaluate_script(COUNT_REQUESTS)
    assert_selector "#service-filter input[value='#{services(:group_session).id}']:not(:checked)", visible: :all
    assert_selector "#service-filter input[value='#{services(:haircut).id}']:checked", visible: :all
  end

  test "going to the List and back renders one calendar" do
    login_as_admin
    page.driver.browser.logs.get(:browser) # drop the earlier tests' console entries
    page.execute_script("window.localStorage.removeItem('OpenAppointments.CalendarFilter')")
    visit "/calendar"
    wait_for_requests(1)
    within("#header") { click_on "List" }
    assert_selector "#day-filter", wait: 10
    page.go_back
    assert_selector "#calendar .fc-view-harness", wait: 10
    assert_selector "#calendar .fc-toolbar", count: 1
    errors = page.driver.browser.logs.get(:browser).select { |log| log.level == "SEVERE" }.map(&:message)
                 .reject { |m| m.include?("404") }
    assert_empty errors
  end
end
