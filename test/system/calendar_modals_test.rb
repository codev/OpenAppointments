require "application_system_test_case"

# Appointment and unavailability dialogs on the calendar pages. Written against
# the jQuery version (labels, visible text and popover buttons), so it must pass
# on both.
class CalendarModalsTest < ApplicationSystemTestCase
  # The pages open on the browser's today, so the dates are today's.
  def today = Date.current.strftime("%d/%m/%Y")

  setup do
    Setting.set("display_email", "1")
    Setting.set("display_phone_number", "1")
    login_as_admin
  end

  # The calendar page's week view shows every event whatever the working plan.
  def open_event(title)
    visit calendar_url unless current_path == "/calendar"
    assert_selector ".fc-event", text: title, wait: 10
    find(".fc-event", text: title).click
    assert_selector ".popover", wait: 5
  end

  test "add an appointment for an existing customer, edit it, then cancel it with a reason" do
    begin
      visit appointments_url
      assert_selector "#insert-appointment", visible: :all, wait: 10
      find("#calendar-actions [data-bs-toggle=dropdown]").click
      find("#insert-appointment").click
      assert_selector "#appointments-modal", visible: true, wait: 5
      within("#appointments-modal") do
        select "Trim Cut", from: "select-service"
        select "Zane", from: "select-provider"
        find("#start-datetime").set("#{today} 2:00 pm\t")
        find("#end-datetime").set("#{today} 2:30 pm\t")
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
      assert_equal "14:00", appointment.start_datetime.strftime("%H:%M")

      open_event("Trim Cut")
      within(".popover") { click_on "Edit" }
      assert_selector "#appointments-modal", visible: true, wait: 5
      within("#appointments-modal") do
        assert_field "appointment-notes", with: /Fringe only|/
        fill_in "appointment-notes", with: "Fringe and wash"
        click_on "Save"
      end
      confirm_modal "Appointment Update", "No"
      assert_text "Appointment saved", wait: 10
      assert_includes Appointment.appointments.pluck(:notes), "Fringe and wash"

      open_event("Trim Cut")
      within(".popover") { click_on "Cancel" }
      assert_selector "#message-modal .modal-title", text: "Cancel Appointment", wait: 5
      within("#message-modal") { click_on "Yes" }
      assert_selector "#message-modal textarea", wait: 5
      find("#message-modal textarea").set("Client away")
      within("#message-modal .modal-footer") { click_on "Cancel" }
      assert_no_selector "#message-modal", wait: 5
      assert_no_selector ".fc-event", text: "Trim Cut", wait: 10
      cancelled = Appointment.where("notes LIKE ?", "Fringe%").sole
      assert_equal "cancelled", cancelled.appointment_status&.kind
      assert_includes cancelled.notes, "Client away"
    end
  end

  test "add and delete an unavailability" do
    begin
      visit appointments_url
      find("#calendar-actions [data-bs-toggle=dropdown]").click
      find("#insert-unavailability").click
      assert_selector "#unavailabilities-modal", visible: true, wait: 5
      within("#unavailabilities-modal") do
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
