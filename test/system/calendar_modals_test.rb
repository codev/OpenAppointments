require "application_system_test_case"

# Appointment and unavailability dialogs on the calendar pages. Written against
# the jQuery version (labels, visible text and popover buttons), so it must pass
# on both.
class CalendarModalsTest < ApplicationSystemTestCase
  # The calendar opens on the current week, so events sit today or just around now.
  def today = Date.current.strftime("%d/%m/%Y")
  def soon = @soon ||= Time.at((Time.now.to_i / 900 + 2) * 900)

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

  test "an ended appointment's popover offers no Cancel and the buttons stay inside the popover" do
    start = Time.now.change(sec: 0) - 40.minutes
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
