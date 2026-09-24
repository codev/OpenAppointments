require "application_system_test_case"

class BookingWizardTest < ApplicationSystemTestCase
  test "service first navigation reaches the time step" do
    visit root_url
    assert_selector "#wizard-frame-1", visible: :visible, wait: 5
    assert_selector "#select-service", visible: :visible

    select services(:haircut).name, from: "select-service"
    find("#button-next-1").click

    assert_selector "#wizard-frame-2", visible: :visible, wait: 5
    select users(:zane).name, from: "select-provider"
    find("#button-next-2").click

    assert_selector "#wizard-frame-3", visible: :visible, wait: 5
    # flatpickr swaps the date input for its own alt input, so #select-date stays hidden.
    assert_selector "#select-date", visible: :all

    find("#button-back-3").click
    assert_selector "#wizard-frame-2", visible: :visible, wait: 5
  end

  test "provider first navigation reaches the time step" do
    visit root_url(first: "provider")
    assert_selector "#wizard-frame-1", visible: :visible, wait: 5
    assert_selector "#select-provider", visible: :visible

    select users(:zane).name, from: "select-provider"
    find("#button-next-1").click

    assert_selector "#wizard-frame-2", visible: :visible, wait: 5
    select services(:haircut).name, from: "select-service"
    find("#button-next-2").click

    assert_selector "#wizard-frame-3", visible: :visible, wait: 5
  end

  test "cards mode drives the wizard through card clicks" do
    Setting.set("booking_display_mode", "cards")
    visit root_url
    assert_selector "#category-cards .booking-card", wait: 5

    find("#category-cards .booking-card", match: :first).click
    find(".service-cards .booking-card[data-service-id='#{services(:haircut).id}']", wait: 5).click
    find("#button-next-1").click

    assert_selector "#wizard-frame-2", visible: :visible, wait: 5
    assert_selector "#provider-cards .booking-card", wait: 5
    find("#provider-cards .booking-card[data-provider-id='#{users(:zane).id}']").click
    find("#button-next-2").click

    assert_selector "#wizard-frame-3", visible: :visible, wait: 5

    # Going back to the start resets to the category view with nothing selected.
    find("#button-back-3").click
    assert_selector "#wizard-frame-2", visible: :visible, wait: 5
    find("#button-back-2").click
    assert_selector "#wizard-frame-1", visible: :visible, wait: 5
    assert_no_selector "#category-cards .booking-card.selected"
    assert_no_selector ".service-cards:not(.d-none) .booking-card", visible: :all
    assert_equal "", find("#select-service", visible: :hidden).value
  end

  test "the header follows the choices, completed steps tick and jump back, steps have tooltips" do
    visit root_url
    assert_selector "#wizard-frame-1", visible: :visible, wait: 5
    assert_selector ".display-booking-selection", text: "Service"
    assert page.evaluate_script("!!document.querySelector('#step-1')._tippy"), "steps need tooltips"

    select services(:haircut).name, from: "select-service"
    assert_selector ".display-booking-selection", text: services(:haircut).name
    find("#button-next-1").click
    assert_selector "#wizard-frame-2", visible: :visible, wait: 5
    # The only provider is preselected, so the header names them straight away.
    assert_selector ".display-booking-selection", text: "#{services(:haircut).name} │ Zane"
    assert_selector "#step-1.completed-step .step-check", visible: :visible
    select users(:zane).name, from: "select-provider"
    find("#button-next-2").click
    assert_selector "#wizard-frame-3", visible: :visible, wait: 5
    assert_selector "#step-2.completed-step"

    find("#step-1").click
    assert_selector "#wizard-frame-1", visible: :visible, wait: 5
    assert_no_selector "#steps .completed-step"
    assert_equal services(:haircut).id.to_s, find("#select-service").value
  end

  test "the cookie banner shows and its link opens the notice" do
    Setting.set("display_cookie_notice", "1")
    Setting.set("cookie_notice_content", "We use one cookie.")
    visit root_url
    assert_selector ".cc-window", wait: 5
    find(".cc-link[data-bs-target='#cookie-notice-modal']").click
    assert_selector "#cookie-notice-modal.show", text: "We use one cookie.", wait: 5
  end

  test "first page blocks next until a choice is made" do
    visit root_url
    assert_selector "#wizard-frame-1", visible: :visible, wait: 5
    find("#button-next-1").click
    assert_selector "#wizard-frame-1", visible: :visible
    assert_no_selector "#wizard-frame-2", visible: :visible
  end
end

# Written before the Rails + Turbo conversion: labels, visible text and stable
# ids only, so it must pass on both versions.
class BookingWizardFlowTest < ApplicationSystemTestCase
  setup do
    Setting.set("display_email", "1")
    Setting.set("display_phone_number", "1")
  end

  # A second provider so the Any Provider option appears.
  def second_provider
    provider = User.create!(name: "Riley", email: "riley@example.org", role: Role.find_by!(slug: Role::PROVIDER))
    provider.create_settings!(username: "riley", password: Passwords.hash("rileypass1"),
                              working_plan: users(:zane).settings.working_plan)
    ServiceProviderLink.create!(id_users: provider.id, id_services: services(:haircut).id)
    provider
  end

  test "a customer books an appointment end to end and then reschedules it" do
    date = working_day
    visit root_url
    assert_selector "#wizard-frame-1", visible: :visible, wait: 5
    select services(:haircut).name, from: "select-service"
    find("#button-next-1").click
    select users(:zane).name, from: "select-provider"
    find("#button-next-2").click

    assert_selector "#wizard-frame-3", visible: :visible, wait: 5
    find(".flatpickr-day[aria-label='#{date.strftime('%B %-d, %Y')}']", wait: 10).click
    assert_selector "#available-hours .available-hour", minimum: 2, wait: 10
    find("#available-hours .available-hour", text: /\A9:30 am\z/).click
    find("#button-next-3").click

    assert_selector "#wizard-frame-4", visible: :visible, wait: 5
    fill_in "name", with: "Walk In"
    fill_in "email", with: "walkin@example.org"
    find("#button-next-4").click

    assert_selector "#wizard-frame-5", visible: :visible, wait: 5
    assert_text "Walk In"
    assert_text services(:haircut).name
    click_on "Confirm"

    assert_text "Your appointment has been successfully registered", wait: 10
    appointment = Appointment.appointments.find_by!(start_datetime: date.to_time.change(hour: 9, min: 30))
    assert_equal "walkin@example.org", appointment.customer.email
    assert_equal users(:zane).id, appointment.id_users_provider
    assert_equal "booked", appointment.appointment_status.kind

    # Reschedule to the next free hour through the public link.
    visit "/booking/reschedule/#{appointment.booking_hash}"
    assert_selector "#wizard-frame-3, #wizard-frame-1", visible: :visible, wait: 10
    if page.has_selector?("#wizard-frame-1", visible: :visible, wait: 1)
      find("#button-next-1").click
      find("#button-next-2").click
    end
    assert_selector "#wizard-frame-3", visible: :visible, wait: 5
    find(".flatpickr-day[aria-label='#{date.strftime('%B %-d, %Y')}']", wait: 10).click
    assert_selector "#available-hours .available-hour", minimum: 2, wait: 10
    find("#available-hours .available-hour", text: /\A10:00 am\z/).click
    find("#button-next-3").click
    assert_selector "#wizard-frame-4", visible: :visible, wait: 5
    find("#button-next-4").click
    assert_selector "#wizard-frame-5", visible: :visible, wait: 5
    click_on "Update"

    assert_text "successfully", wait: 10
    replacement = Appointment.appointments.order(:id).last
    assert_equal date.to_time.change(hour: 10), replacement.start_datetime
    assert_equal "rescheduled", appointment.reload.appointment_status.kind
  end

  test "cancelling from the reschedule link asks for a reason" do
    date = working_day
    appointment = Appointment.create!(id_users_provider: users(:zane).id, id_users_customer: users(:jx).id,
                                      id_services: services(:haircut).id, start_datetime: date.to_time.change(hour: 14),
                                      end_datetime: date.to_time.change(hour: 14, min: 30),
                                      appointment_status: AppointmentStatus.of("booked"))
    visit "/booking/reschedule/#{appointment.booking_hash}"
    assert_selector "#cancel-appointment", wait: 10
    find("#cancel-appointment").click
    wait_for_modal
    find("#cancel-appointment-confirm").click # the reason is required
    assert_selector "#cancel-appointment-modal.show"
    fill_in "cancellation-reason", with: "Moving house"
    find("#cancel-appointment-confirm").click
    assert_no_selector "#cancel-appointment", wait: 10
    assert_equal "cancelled", appointment.reload.appointment_status.kind
    assert_includes appointment.notes, "Moving house"
  end

  test "any provider offers the union of hours and books an actual provider" do
    Setting.set("display_any_provider", "1")
    second_provider
    date = working_day
    visit root_url
    assert_selector "#wizard-frame-1", visible: :visible, wait: 5
    select services(:haircut).name, from: "select-service"
    find("#button-next-1").click
    select "Any Provider", from: "select-provider"
    find("#button-next-2").click
    assert_selector "#wizard-frame-3", visible: :visible, wait: 5
    find(".flatpickr-day[aria-label='#{date.strftime('%B %-d, %Y')}']", wait: 10).click
    assert_selector "#available-hours .available-hour", minimum: 2, wait: 10
    find("#available-hours .available-hour", text: /\A11:00 am\z/).click
    find("#button-next-3").click
    fill_in "name", with: "Any One"
    fill_in "email", with: "anyone@example.org"
    find("#button-next-4").click
    assert_selector "#wizard-frame-5", visible: :visible, wait: 5
    click_on "Confirm"
    assert_text "successfully registered", wait: 10
    appointment = Appointment.appointments.order(:id).last
    assert_includes User.providers.pluck(:id), appointment.id_users_provider
  end
end

# Rails + Turbo only: the whole window's hours arrive with the time step.
class BookingWizardWindowTest < ApplicationSystemTestCase
  setup { Setting.set("display_email", "1") }

  def to_time_step
    visit root_url
    select services(:haircut).name, from: "select-service"
    find("#button-next-1").click
    select users(:zane).name, from: "select-provider"
    find("#button-next-2").click
    assert_selector "#wizard-frame-3", visible: :visible, wait: 5
  end

  test "switching days needs no request and the browser back button walks the steps" do
    to_time_step
    assert_match(/step=time/, current_url)
    page.execute_script("window.__requests = 0; const open = XMLHttpRequest.prototype.open; XMLHttpRequest.prototype.open = function(...a) { window.__requests++; return open.apply(this, a); }; const f = window.fetch; window.fetch = (...a) => { window.__requests++; return f(...a); }")

    first_day = working_day(0)
    second_day = working_day(1)
    find(".flatpickr-day[aria-label='#{first_day.strftime('%B %-d, %Y')}']").click
    assert_selector "#available-hours .available-hour", minimum: 2
    find(".flatpickr-day[aria-label='#{second_day.strftime('%B %-d, %Y')}']").click
    assert_selector "#available-hours .available-hour", minimum: 2
    assert_equal 0, page.evaluate_script("window.__requests"), "day browsing must not hit the server"

    page.go_back
    assert_selector "#wizard-frame-2", visible: :visible, wait: 5
    assert_equal users(:zane).id.to_s, find("#select-provider").value
    # The first step's URL predates the choice, so browser-back shows it clean;
    # the wizard's own Back buttons carry the selection.
    page.go_back
    assert_selector "#wizard-frame-1", visible: :visible, wait: 5
  end

  test "the details step marks missing fields and shows the message below them" do
    to_time_step
    date = working_day(0)
    find(".flatpickr-day[aria-label='#{date.strftime('%B %-d, %Y')}']").click
    find("#available-hours .available-hour", text: /\A9:30 am\z/, wait: 5).click
    find("#button-next-3").click
    assert_selector "#wizard-frame-4", visible: :visible, wait: 5
    find("#button-next-4").click
    assert_selector "#name.is-invalid"
    assert_selector "#form-message", text: I18n.t("ea.fields_are_required"), visible: :visible
    assert_selector "#wizard-frame-4", visible: :visible
    assert_no_selector "#wizard-frame-5"

    fill_in "name", with: "Marked Up"
    fill_in "email", with: "nope"
    find("#button-next-4").click
    assert_no_selector "#name.is-invalid"
    assert_selector "#email.is-invalid"
    assert_selector "#form-message", text: I18n.t("ea.invalid_email")
  end

  test "the time step refuses Next until an hour is chosen" do
    to_time_step
    find("#button-next-3").click
    assert_selector "#select-hour-prompt", text: I18n.t("ea.appointment_hour_missing")
    assert_selector "#wizard-frame-3", visible: :visible
    assert_no_selector "#wizard-frame-4"
  end

  test "the indicator follows the frame, the details post leaves the address alone and Back stays in the frame" do
    Setting.set("first_weekday", "monday")
    to_time_step
    assert_selector "#steps #step-3.active-step"
    assert_no_selector "#steps #step-1.active-step"
    assert_equal "Mon", first(".flatpickr-weekday").text.strip

    date = working_day(0)
    find(".flatpickr-day[aria-label='#{date.strftime('%B %-d, %Y')}']").click
    find("#available-hours .available-hour", text: /\A9:30 am\z/, wait: 5).click
    find("#button-next-3").click
    assert_selector "#wizard-frame-4", visible: :visible, wait: 5
    page.execute_script("window.__sameDocument = true")
    fill_in "name", with: "Stepper"
    fill_in "email", with: "stepper@example.org"
    find("#button-next-4").click
    assert_selector "#wizard-frame-5", visible: :visible, wait: 5
    assert_selector "#steps #step-5.active-step"
    assert_no_match(%r{/booking/confirm}, current_url)

    find("#button-back-5").click
    assert_selector "#wizard-frame-4", visible: :visible, wait: 5
    assert_equal "Stepper", find("#name").value
    assert page.evaluate_script("window.__sameDocument === true"), "Back must not reload the page"
  end

  test "details typed this session come back after revisiting an earlier step" do
    to_time_step
    date = working_day(0)
    find(".flatpickr-day[aria-label='#{date.strftime('%B %-d, %Y')}']").click
    find("#available-hours .available-hour", text: /\A9:30 am\z/, wait: 5).click
    find("#button-next-3").click
    assert_selector "#wizard-frame-4", visible: :visible, wait: 5
    fill_in "name", with: "Draft Person"
    fill_in "email", with: "draft@example.org"
    find("#button-next-4").click
    assert_selector "#wizard-frame-5", visible: :visible, wait: 5

    find("#step-1").click
    assert_selector "#wizard-frame-1", visible: :visible, wait: 5
    find("#button-next-1").click
    find("#button-next-2").click
    assert_selector "#wizard-frame-3", visible: :visible, wait: 5
    # A fresh service choice starts the times over; the details are what must come back.
    find(".flatpickr-day[aria-label='#{date.strftime('%B %-d, %Y')}']").click
    find("#available-hours .available-hour", text: /\A9:30 am\z/, wait: 5).click
    find("#button-next-3").click
    assert_selector "#wizard-frame-4", visible: :visible, wait: 5
    # The draft is filled in on the frame's load event, after the fields exist.
    assert_field "name", with: "Draft Person", wait: 5
    assert_field "email", with: "draft@example.org", wait: 5
    assert_not find("#remember-me").checked?
  end

  test "the timezone select relabels the hours and travels to the customer record" do
    Setting.set("timezone_support", "1")
    to_time_step
    date = working_day(0)
    find(".flatpickr-day[aria-label='#{date.strftime('%B %-d, %Y')}']").click
    find("#available-hours .available-hour", text: /\A9:30 am\z/, wait: 5).click
    select "New_York (-5:00)", from: "select-timezone"
    assert_selector "#available-hours .available-hour.selected-hour", text: /\A4:30 am\z/
    find("#button-next-3").click
    assert_selector "#wizard-frame-4", visible: :visible, wait: 5
    fill_in "name", with: "Far Away"
    fill_in "email", with: "far@example.org"
    find("#button-next-4").click
    assert_selector "#wizard-frame-5 #appointment-details", text: /4:30 am/, wait: 5
    assert_selector "#wizard-frame-5 #appointment-details", text: /New_York/
    click_on "Confirm"
    assert_text "successfully registered", wait: 10
    assert_equal "America/New_York", User.customers.find_by!(email: "far@example.org").timezone
  end

  test "a slot taken while choosing returns to a fresh time step with the message" do
    date = working_day(0)
    to_time_step
    find(".flatpickr-day[aria-label='#{date.strftime('%B %-d, %Y')}']").click
    find("#available-hours .available-hour", text: /\A9:30 am\z/, wait: 5).click
    find("#button-next-3").click
    assert_selector "#wizard-frame-4", visible: :visible, wait: 5
    fill_in "name", with: "Too Slow"
    fill_in "email", with: "slow@example.org"

    # Someone else books the slot meanwhile.
    Appointment.create!(id_users_provider: users(:zane).id, id_users_customer: users(:jx).id, id_services: services(:haircut).id,
                        start_datetime: date.to_time.change(hour: 9, min: 30), end_datetime: date.to_time.change(hour: 10),
                        appointment_status: AppointmentStatus.of("booked"))

    find("#button-next-4").click
    assert_selector "#wizard-frame-5", visible: :visible, wait: 5
    click_on "Confirm"

    assert_selector "#wizard-frame-3", visible: :visible, wait: 10
    assert_selector ".alert-danger", text: I18n.t("ea.requested_hour_is_unavailable")
    find(".flatpickr-day[aria-label='#{date.strftime('%B %-d, %Y')}']").click
    assert_no_selector "#available-hours .available-hour", text: /\A9:30 am\z/
    assert_selector "#available-hours .available-hour", text: /\A10:00 am\z/
    assert_nil Appointment.find_by(notes: "Too Slow")
  end
end
