require "application_system_test_case"

# Appointment and unavailability dialogs on the calendar pages. Written against
# the jQuery version (labels, visible text and popover buttons), so it must pass
# on both.
class CalendarModalsTest < ApplicationSystemTestCase
  # The calendar opens on the current week, so events sit today or just around now.
  def today = Date.current.strftime("%d/%m/%Y")
  def soon = @soon ||= Time.at((wall_now.to_i / 900 + 2) * 900)

  # Stored times are the stylist's wall clock and the browser runs in London,
  # whatever zone the machine running the tests is in.
  def wall_now
    now = Time.now.in_time_zone(BROWSER_TIMEZONE)
    Time.new(now.year, now.month, now.day, now.hour, now.min, 0)
  end

  setup do
    Setting.set("display_email", "1")
    Setting.set("display_phone_number", "1")
    login_as_admin
  end

  # The calendar page's week view shows every event whatever the working plan.
  # Events early or late in the day sit outside the scrolled time grid.
  def open_event(title)
    visit calendar_url unless current_path == "/calendar"
    page.document.synchronize(10) do
      found = page.evaluate_script(<<~JS, title)
        (() => {
          const event = [...document.querySelectorAll('.fc-event')].find((e) => e.textContent.includes(arguments[0]));
          event?.scrollIntoView({block: 'center'});
          return !!event;
        })()
      JS
      raise Capybara::ElementNotFound, title unless found
    end
    # An event across midnight is drawn in two pieces; either opens it.
    find(".fc-event", text: title, match: :first).click
    assert_selector ".popover", wait: 5
  end

  test "add an appointment for an existing customer, edit it, then cancel it with a reason" do
    begin
      visit appointments_url
      assert_selector "#insert-appointment", visible: :all, wait: 10
      find("#calendar-actions [data-bs-toggle=dropdown]").click
      find("#insert-appointment").click
      assert_selector "#save-appointment", visible: true, wait: 5
      wait_for_modal
      within(find("#save-appointment").ancestor(".modal")) do
        select "Trim Cut", from: "select-service"
        select "Zane", from: "select-provider"
        # Ahead of now, so the appointment has not ended and can still be cancelled.
        find("#start-datetime").set("#{soon.strftime('%d/%m/%Y %-l:%M %P')}\t")
        find("#end-datetime").set("#{(soon + 30.minutes).strftime('%d/%m/%Y %-l:%M %P')}\t")
        click_on "Select"
        assert_selector "#existing-customers-list div", text: "JX", wait: 5
        find("#existing-customers-list div", text: "JX").click
        assert_field "name", with: "JX"
        fill_in "appointment-notes", with: "Fringe only"
        click_on "Save"
      end
      confirm_modal "New Appointment", "No"
      assert_text "Appointment saved", wait: 10
      appointment = Appointment.appointments.find_by!(notes: "Fringe only")
      assert_equal users(:jx).id, appointment.id_users_customer
      assert_equal soon.strftime("%H:%M"), appointment.start_datetime.strftime("%H:%M")

      open_event("Trim Cut")
      within(".popover") { click_on "Edit" }
      assert_selector "#save-appointment", visible: true, wait: 5
      wait_for_modal
      within(find("#save-appointment").ancestor(".modal")) do
        # The frame fills the form after the modal shows: typing before that is lost.
        assert_field "appointment-notes", with: "Fringe only", wait: 5
        fill_in "appointment-notes", with: "Fringe and wash"
        click_on "Save"
      end
      confirm_modal "Appointment Update", "No"
      assert_text "Appointment saved", wait: 10
      assert_includes Appointment.appointments.pluck(:notes), "Fringe and wash"

      open_event("Trim Cut")
      within(".popover") { click_on "Cancel" }
      assert_selector ".modal.show .modal-title", text: "Cancel Appointment", wait: 5
      within(".modal.show") { has_button?("Yes") ? click_on("Yes") : choose("Yes") }
      assert_selector "#cancellation-reason", visible: true, wait: 5
      wait_for_modal
      find("#cancellation-reason").set("Client away")
      within(".modal.show .modal-footer") { click_on "Cancel" }
      assert_no_selector ".modal.show", wait: 5
      assert_no_selector ".fc-event", text: "Trim Cut", wait: 10
      cancelled = Appointment.where("notes LIKE ?", "Fringe%").sole
      assert_equal "cancelled", cancelled.appointment_status&.kind
      assert_includes cancelled.notes, "Client away"
    end
  end

  test "appointment boxes are opaque so overlapping ones stay readable" do
    Appointment.create!(provider: users(:zane), customer: users(:jx), service: services(:haircut),
                        start_datetime: soon, end_datetime: soon + 30.minutes, appointment_status: AppointmentStatus.of("booked"))
    visit calendar_url
    assert_selector ".fc-event", text: "JX", wait: 10
    background = page.evaluate_script(<<~JS)
      getComputedStyle([...document.querySelectorAll('.fc-event')].find((e) => e.textContent.includes('JX'))).backgroundColor
    JS
    assert_match(/\Argb\(\d+, \d+, \d+\)\z/, background, "expected an opaque colour, got #{background}")
  end

  def slot_times
    page.evaluate_script("[...document.querySelectorAll('td.fc-timegrid-slot-label[data-time]')].map((td) => td.dataset.time)")
  end

  test "the day runs from the first working stylist or appointment to the last" do
    day = { "start" => "10:00", "end" => "17:00", "breaks" => [] }
    plan = %w[monday tuesday wednesday thursday friday saturday sunday].index_with { day }
    users(:zane).settings.update!(working_plan: plan.to_json)
    # Unavailabilities and stylists who do not offer the chosen service do not widen the day.
    off = Time.zone.parse("#{Date.current} 06:00")
    Appointment.create!(provider: users(:zane), start_datetime: off, end_datetime: off + 1.hour, is_unavailability: true)
    early_bird = User.create!(name: "Early Bird", email: "early@example.org", role: users(:zane).role, timezone: "Europe/London")
    early_bird.create_settings!(username: "earlybird", password: Passwords.hash("stylistpass1"),
                                working_plan: plan.transform_values { { "start" => "07:00", "end" => "12:00", "breaks" => [] } }.to_json)
    other = Service.create!(name: "Other Service", duration: 30, price: 0, currency: "GBP", slot_interval: 15,
                            attendants_number: 1, booking_slug: "other-svc")
    ServiceProviderLink.create!(id_users: early_bird.id, id_services: other.id)

    page.execute_script("window.localStorage.clear()")
    visit calendar_url
    find("#service-filter .dropdown-toggle", wait: 10).click
    within("#service-filter .dropdown-menu") do
      click_on "Clear Services"
      check "Trim Cut"
    end
    assert_selector "td.fc-timegrid-slot-label[data-time]", wait: 10
    page.document.synchronize(10) { raise Capybara::ExpectationNotMet unless slot_times.first == "10:00:00" }
    assert_equal "16:45:00", slot_times.last

    early = Time.zone.parse("#{Date.current} 08:30")
    Appointment.create!(provider: users(:zane), customer: users(:jx), service: services(:haircut),
                        start_datetime: early, end_datetime: early + 30.minutes, appointment_status: AppointmentStatus.of("booked"))
    visit calendar_url
    page.document.synchronize(10) { raise Capybara::ExpectationNotMet unless slot_times.first == "08:00:00" }
    assert_equal "16:45:00", slot_times.last
  end

  def event_titles
    page.evaluate_script("[...document.querySelectorAll('#calendar .fc-timegrid-event .fc-event-title')].map((e) => e.textContent).sort()")
  end

  def fetches
    page.evaluate_script("performance.getEntriesByType('resource').filter((e) => e.name.includes('get_calendar_appointments')).length")
  end

  def assert_event_titles(expected)
    page.document.synchronize(5) { raise Capybara::ExpectationNotMet, event_titles.inspect unless event_titles == expected }
  end

  test "Stylists and Services tick boxes filter the calendar in the browser and are remembered" do
    riley = User.create!(name: "Riley", email: "riley@example.org", role: users(:zane).role, timezone: "Europe/London",
                         color: "#aa3377")
    riley.create_settings!(username: "riley", password: Passwords.hash("rileypass1"), working_plan: user_settings(:zane).working_plan)
    ServiceProviderLink.create!(id_users: riley.id, id_services: services(:group_session).id)
    users(:zane).update!(color: "#228833")
    Appointment.create!(provider: users(:zane), customer: users(:jx), service: services(:haircut),
                        start_datetime: soon, end_datetime: soon + 30.minutes, appointment_status: AppointmentStatus.of("booked"))
    Appointment.create!(provider: riley, customer: users(:jx), service: services(:group_session),
                        start_datetime: soon, end_datetime: soon + 30.minutes, appointment_status: AppointmentStatus.of("booked"))
    page.execute_script("window.localStorage.clear()")
    visit calendar_url
    assert_event_titles [ "JX - Group Session", "JX - Trim Cut" ]
    assert_selector "#calendar-legend", visible: true
    loaded = fetches

    show_only_stylist("Zane")
    assert_event_titles [ "JX - Trim Cut" ]
    assert_selector "#provider-filter .dropdown-toggle", text: "Providers (1)"
    assert_equal users(:zane).id.to_s, page.evaluate_script("document.getElementById('select-filter-item').value")
    assert_selector "#enable-sync", visible: true, wait: 5
    assert_selector "#calendar-legend", visible: false
    widths = page.evaluate_script(<<~JS)
      ({ button: document.querySelector('#provider-filter .dropdown-toggle').getBoundingClientRect().width,
         row: document.getElementById('calendar-toolbar').getBoundingClientRect().width })
    JS
    assert_operator widths["button"], :<, widths["row"] / 3, "filter button spans #{widths['button']} of #{widths['row']}px"

    find("#provider-filter .dropdown-toggle").click
    within("#provider-filter .dropdown-menu") { check "Riley" }
    assert_event_titles [ "JX - Group Session", "JX - Trim Cut" ]
    assert_equal "all", page.evaluate_script("document.getElementById('select-filter-item').value")
    assert_selector "#enable-sync", visible: false, wait: 5
    within("#provider-filter .dropdown-menu") { click_on "Clear Providers" }
    assert_event_titles []
    within("#provider-filter .dropdown-menu") { click_on "All Providers" }
    assert_event_titles [ "JX - Group Session", "JX - Trim Cut" ]

    find("#service-filter .dropdown-toggle").click
    within("#service-filter .dropdown-menu") do
      click_on "Clear Services"
      check services(:haircut).name
    end
    # Several stylists and one service: titled by stylist.
    assert_event_titles [ "JX - Zane" ]
    assert_equal loaded, fetches, "ticking a box redraws without fetching"

    visit calendar_url
    assert_event_titles [ "JX - Zane" ]
    assert_selector "#service-filter .dropdown-toggle", text: "Services (1)"
    assert_selector "#provider-filter .dropdown-toggle", text: /\AProviders\z/
  end

  test "a stylist's calendar has no Stylists dropdown and shows only their own appointments" do
    riley = User.create!(name: "Riley", email: "riley@example.org", role: users(:zane).role, timezone: "Europe/London")
    ServiceProviderLink.create!(id_users: riley.id, id_services: services(:haircut).id)
    Appointment.create!(provider: users(:zane), customer: users(:jx), service: services(:haircut),
                        start_datetime: soon, end_datetime: soon + 30.minutes, appointment_status: AppointmentStatus.of("booked"))
    Appointment.create!(provider: riley, customer: users(:jx), service: services(:group_session),
                        start_datetime: soon, end_datetime: soon + 30.minutes, appointment_status: AppointmentStatus.of("booked"))
    visit logout_url
    visit login_url
    fill_in "username", with: "janedoe"
    fill_in "password", with: "janedoe1"
    find("#login").click
    assert_no_current_path "/login", wait: 10
    page.execute_script("window.localStorage.clear()")
    visit calendar_url
    assert_event_titles [ "JX - Trim Cut" ]
    assert_no_selector "#provider-filter"
    assert_selector "#calendar-feed", visible: true, wait: 5
  end

  test "on a tablet Enable sync is only as wide as its icon and text" do
    resize_window(800, 900)
    visit calendar_url
    show_only_stylist("Zane")
    assert_selector "#enable-sync", visible: true, wait: 5
    widths = page.evaluate_script(<<~JS)
      (() => {
        const button = document.getElementById('enable-sync');
        return { button: button.getBoundingClientRect().width,
                 row: document.getElementById('calendar-actions').getBoundingClientRect().width };
      })()
    JS
    assert_operator widths["button"], :<, widths["row"] / 2, "Enable sync spans #{widths['button']} of #{widths['row']}px"
  end

  test "an ended appointment's popover offers no Cancel and the buttons stay inside the popover" do
    start = wall_now - 40.minutes
    Appointment.create!(provider: users(:zane), customer: users(:jx), service: services(:haircut),
                        start_datetime: start, end_datetime: start + 30.minutes, appointment_status: AppointmentStatus.of("booked"))
    visit calendar_url
    open_event("JX")
    within(".popover") do
      assert_selector ".edit-popover", visible: true
      assert_no_selector ".cancel-popover", visible: true
    end

    # Not ended, so all five buttons show.
    Appointment.last.update!(start_datetime: soon, end_datetime: soon + 30.minutes)
    visit calendar_url
    open_event("JX")
    assert_selector ".popover .cancel-popover", visible: true
    overflow = page.evaluate_script(<<~JS)
      (() => {
        const box = document.querySelector('.popover').getBoundingClientRect();
        return [...document.querySelectorAll('.popover .btn')].filter((b) => b.offsetParent)
          .some((b) => { const r = b.getBoundingClientRect(); return r.left < box.left || r.right > box.right; });
      })()
    JS
    assert_not overflow, "popover buttons must stay inside the popover"
  end

  test "an appointment saves at a time off the quarter hour, as meetings use" do
    start = soon + 2.minutes
    visit appointments_url
    assert_selector "#insert-appointment", visible: :all, wait: 10
    find("#calendar-actions [data-bs-toggle=dropdown]").click
    find("#insert-appointment").click
    assert_selector "#save-appointment", visible: true, wait: 5
    wait_for_modal
    within(find("#save-appointment").ancestor(".modal")) do
      select "Trim Cut", from: "select-service"
      select "Zane", from: "select-provider"
      find("#start-datetime").set("#{start.strftime('%d/%m/%Y %-l:%M %P')}\t")
      find("#end-datetime").set("#{(start + 30.minutes).strftime('%d/%m/%Y %-l:%M %P')}\t")
      click_on "Select"
      find("#existing-customers-list div", text: "JX", wait: 5).click
      fill_in "appointment-notes", with: "Off the grid"
      click_on "Save"
    end
    confirm_modal "New Appointment", "No"
    assert_text "Appointment saved", wait: 10
    assert_equal start.strftime("%H:%M"), Appointment.find_by!(notes: "Off the grid").start_datetime.strftime("%H:%M")
  end

  test "add and delete an unavailability" do
    begin
      visit appointments_url
      find("#calendar-actions [data-bs-toggle=dropdown]").click
      find("#insert-unavailability").click
      assert_selector "#save-unavailability", visible: true, wait: 5
      wait_for_modal
      within(find("#save-unavailability").ancestor(".modal")) do
        select "Zane", from: "unavailability-provider"
        find("#unavailability-start").set("#{today} 3:00 pm\t")
        find("#unavailability-end").set("#{today} 4:00 pm\t")
        fill_in "unavailability-notes", with: "Dentist"
        click_on "Save"
      end
      assert_text "Unavailability saved", wait: 10
      block = Appointment.unavailabilities.find_by!(notes: "Dentist")
      assert_equal "15:00", block.start_datetime.strftime("%H:%M")

      open_event("Dentist")
      within(".popover") { click_on "Delete" }
      assert_no_selector ".fc-event", text: "Dentist", wait: 10
      assert_not Appointment.exists?(block.id)
    end
  end
end
