require "application_system_test_case"

# The server rendered appointments page: provider day columns, filters and
# navigation as URL state, entries opening the event dialog.
class AppointmentsPageTest < ApplicationSystemTestCase
  setup do
    # From tomorrow: the popover shows Cancel only while the appointment is ahead.
    @date = working_day(0)
    Appointment.create!(id_users_provider: users(:zane).id, id_users_customer: users(:jx).id, id_services: services(:haircut).id,
                        start_datetime: @date.to_time.change(hour: 11), end_datetime: @date.to_time.change(hour: 11, min: 30),
                        appointment_status: AppointmentStatus.of("booked"), notes: "Morning cut")
    login_as_admin
  end

  test "columns list the day's entries, a free slot opens a prefilled dialog, and the toolbar is URL state" do
    visit appointments_url(date: @date)
    assert_selector ".provider-column[data-provider-id='#{users(:zane).id}'] h6", text: "Zane", wait: 5
    within(".provider-column[data-provider-id='#{users(:zane).id}']") do
      assert_selector ".day-entry-appointment", text: "JX - Trim Cut"
      assert_selector ".day-entry-appointment", text: "11:00 am - 11:30 am"
      assert_selector ".day-entry-free", minimum: 1
      first(".day-entry-free").click
    end
    assert_selector "#save-appointment", visible: true, wait: 5
    assert_equal users(:zane).id.to_s, find("#select-provider").value
    assert_match(/9:00 am/, find("#start-datetime").value)
    wait_for_modal
    within(find("#save-appointment").ancestor(".modal")) { click_on "Cancel" }
    assert_no_selector ".modal.show", wait: 5

    find(".day-entry-appointment", text: "JX - Trim Cut").click
    assert_selector ".popover", wait: 5
    popover_top, header_bottom = page.evaluate_script(
      "[document.querySelector('.popover').getBoundingClientRect().top, document.getElementById('header').getBoundingClientRect().bottom]"
    )
    assert_operator popover_top, :>=, header_bottom, "the popover is hidden under the header"
    within(".popover", wait: 5) do
      assert_text "JX"
      assert_text "Morning cut"
      assert_selector "a", text: "Messages"
      assert_selector ".cancel-popover", visible: true
      click_on "Edit"
    end
    assert_no_selector ".popover", wait: 5
    assert_selector "#save-appointment", visible: true, wait: 5
    assert_field "appointment-notes", with: "Morning cut"
    wait_for_modal
    within(find("#save-appointment").ancestor(".modal")) { click_on "Cancel" }
    assert_no_selector ".modal.show", wait: 5

    find("#next-day").click
    assert_current_path(/date=#{@date + 1}/, wait: 5)
    find("#previous-day").click
    assert_current_path(/date=#{@date}/, wait: 5)
    select "3 Days", from: "select-day-interval"
    assert_current_path(/days=3/, wait: 5)
    assert_selector ".date-column", count: 3, wait: 5

    find("#status-filter button").click
    uncheck "Booked"
    assert_no_selector ".day-entry-appointment", text: "JX - Trim Cut", wait: 5
    assert_current_path(/statuses/, wait: 5)
  end

  LAYOUT = <<~JS.freeze
    (() => {
      const box = (el) => el.getBoundingClientRect();
      const view = document.querySelector('#calendar .calendar-view');
      return {
        viewWidth: view.clientWidth, scrolls: view.scrollWidth > view.clientWidth,
        title: box(document.querySelector('.date-column-title')),
        columns: [...document.querySelectorAll('.provider-column')].map((el) => {
          const r = box(el); return { top: r.top, bottom: r.bottom, width: r.width };
        })
      };
    })()
  JS

  test "each date lists its stylists one under another at full width" do
    5.times do |index|
      provider = User.create!(name: "Stylist #{index}", email: "stylist#{index}@example.org", role: users(:zane).role,
                              timezone: "Europe/London")
      provider.create_settings!(username: "stylist#{index}", password: Passwords.hash("stylistpass1"),
                                working_plan: user_settings(:zane).working_plan)
      ServiceProviderLink.create!(id_users: provider.id, id_services: services(:haircut).id)
    end
    [ 1400, 800, 420 ].each do |width|
      resize_window(width, 900)
      visit appointments_url(date: @date)
      assert_selector ".provider-column", count: 6, wait: 5
      overlaps = page.evaluate_script(<<~JS)
        (() => {
          const boxes = ['#today', '#select-date', '#toggle-series'].map((s) => document.querySelector(s).getBoundingClientRect());
          const hit = (a, b) => a.left < b.right - 1 && b.left < a.right - 1 && a.top < b.bottom - 1 && b.top < a.bottom - 1;
          return hit(boxes[0], boxes[1]) || hit(boxes[1], boxes[2]) || hit(boxes[0], boxes[2]);
        })()
      JS
      assert_not overlaps, "#{width}px: Today, the date and Repeating Appointments overlap"
      layout = page.evaluate_script(LAYOUT)
      assert_not layout["scrolls"], "#{width}px: the list scrolls sideways"
      assert_operator layout["title"]["bottom"], :<=, layout["columns"].first["top"] + 1, "#{width}px: date heading above the stylists"
      layout["columns"].each_cons(2) do |above, below|
        assert_operator below["top"], :>=, above["bottom"] - 1, "#{width}px: stylists must stack"
      end
      layout["columns"].each do |column|
        assert_operator column["width"], :>=, layout["viewWidth"] * 0.95, "#{width}px: stylist not full width"
      end
    end
  end
end

class AppointmentsPageRefreshTest < ApplicationSystemTestCase
  test "a saved appointment appears in the day column without any filter interaction" do
    date = working_day(0, from: Date.current)
    login_as_admin
    visit appointments_url(date: date)
    assert_selector ".provider-column[data-provider-id='#{users(:zane).id}']", wait: 5
    assert_no_selector ".day-entry-appointment", text: "JX - "

    first(".provider-column .day-entry-free").click
    assert_selector "#save-appointment", visible: true, wait: 5
    wait_for_modal
    within(find("#save-appointment").ancestor(".modal")) do
      click_on "Select"
      assert_selector "#existing-customers-list div", text: "JX", wait: 5
      find("#existing-customers-list div", text: "JX").click
      click_on "Save"
    end
    confirm_modal "New Appointment", "No"
    assert_text "Appointment saved", wait: 10
    assert_selector ".day-entry-appointment", text: "JX - ", wait: 10
    assert_current_path(/date=#{date}/)
  end

  test "the appointments page shows no calendar after the calendar page was visited" do
    login_as_admin
    visit calendar_url
    assert_selector "#calendar .fc-view-harness", wait: 10
    within("#header") { click_on "List", match: :first }
    assert_selector "#day-filter", wait: 5
    sleep 0.5
    assert_no_selector "#calendar .fc-view-harness"
  end

  test "the repeating appointments list stays alone after the day view reloads" do
    login_as_admin
    visit appointments_url
    assert_selector "#day-filter", wait: 5
    find("#toggle-series").click
    assert_selector "#series-view", visible: true, wait: 5
    page.execute_script("document.querySelector('#calendar .calendar-view').dataset.stale = '1'")
    find("#reload-appointments").click
    assert_no_selector ".calendar-view[data-stale]", visible: :all, wait: 5
    assert_selector "#calendar .calendar-view.d-none", visible: :all
    assert_selector "#series-view:not(.d-none)"
    find("#toggle-series").click
    assert_selector "#calendar .calendar-view:not(.d-none)", wait: 5
  end

  test "the reload button still works on the calendar page after the appointments page was visited" do
    login_as_admin
    visit appointments_url
    assert_selector "#day-filter", wait: 5
    within("#header") { click_on "Calendar", match: :first }
    assert_selector "#calendar .fc-view-harness", wait: 10
    page.driver.browser.logs.get(:browser)
    find("#reload-appointments").click
    sleep 0.5
    errors = page.driver.browser.logs.get(:browser).select { |log| log.level == "SEVERE" }.map(&:message).reject { |m| m.include?("404") }
    assert_empty errors
  end
end
