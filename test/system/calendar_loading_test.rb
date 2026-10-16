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

  # Stored times are the stylist's wall clock and the browser runs in London.
  def soon
    now = Time.now.in_time_zone(BROWSER_TIMEZONE)
    Time.at((Time.new(now.year, now.month, now.day, now.hour, now.min, 0).to_i / 900 + 2) * 900)
  end

  # The opaque tint calendar_events.js mixes from a hex colour.
  def tint(hex)
    "rgb(#{hex.delete('#').scan(/../).map { |c| (255 - (255 - c.to_i(16)) * 0.28).round }.join(', ')})"
  end

  def rgb(hex) = "rgb(#{hex.delete('#').scan(/../).map { |c| c.to_i(16) }.join(', ')})"

  def event_style(title)
    page.evaluate_script(<<~JS, title)
      (() => {
          const event = [...document.querySelectorAll('#calendar .fc-event')].find((e) => e.textContent.includes(arguments[0]));
          if (!event) return null;
          const style = getComputedStyle(event);
          return { fill: style.backgroundColor, border: style.borderLeftColor, edge: style.borderLeftStyle };
      })()
    JS
  end

  def assert_event_style(title, fill:, border:)
    page.document.synchronize(10) do
      style = event_style(title)
      raise Capybara::ExpectationNotMet, "#{title}: #{style.inspect}" unless style == { "fill" => fill, "border" => border, "edge" => "solid" }
    end
  end

  test "events are filled with the stylist colour and edged with the service colour, one stylist or many" do
    riley = User.create!(name: "Riley", email: "riley@example.org", role: users(:zane).role, timezone: "Europe/London")
    riley.create_settings!(username: "riley", password: Passwords.hash("rileypass1"), working_plan: user_settings(:zane).working_plan)
    ServiceProviderLink.create!(id_users: riley.id, id_services: services(:group_session).id)
    users(:zane).update!(color: "#228833")
    services(:haircut).update!(color: "#eb8687")
    services(:group_session).update!(color: "#f3bc7d")
    Appointment.create!(provider: users(:zane), customer: users(:jx), service: services(:haircut), color: "#abe9a4",
                        start_datetime: soon, end_datetime: soon + 30.minutes, appointment_status: AppointmentStatus.of("booked"))
    Appointment.create!(provider: riley, customer: users(:jx), service: services(:group_session), color: "#abe9a4",
                        start_datetime: soon, end_datetime: soon + 30.minutes, appointment_status: AppointmentStatus.of("booked"))
    login_as_admin
    page.execute_script("window.localStorage.removeItem('OpenAppointments.CalendarFilter')")
    visit "/calendar"
    assert_event_style "Trim Cut", fill: tint("#228833"), border: rgb("#eb8687")
    # A stylist with no colour of their own takes the palette's first.
    assert_event_style "Group Session", fill: tint("#7cbae8"), border: rgb("#f3bc7d")
    assert_selector "#calendar-legend .legend-swatch", count: 2

    show_only_stylist("Zane")
    assert_event_style "Trim Cut", fill: tint("#228833"), border: rgb("#eb8687")
  end
end
