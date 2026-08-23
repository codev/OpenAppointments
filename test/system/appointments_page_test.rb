require "application_system_test_case"

# The server rendered appointments page: provider day columns, filters and
# navigation as URL state, entries opening the event dialog.
class AppointmentsPageTest < ApplicationSystemTestCase
  setup do
    # Zane works Monday to Friday in the fixtures; pick the next weekday.
    @date = Date.current
    @date += 1 until (1..5).cover?(@date.wday)
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
    within(find("#save-appointment").ancestor(".modal")) { click_on "Cancel" }
    assert_no_selector ".modal.show", wait: 5

    find(".day-entry-appointment", text: "JX - Trim Cut").click
    assert_selector "#save-appointment", visible: true, wait: 5
    assert_field "appointment-notes", with: "Morning cut"
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
end
