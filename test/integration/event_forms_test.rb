require "test_helper"

# The appointment and unavailability dialog forms served into the calendar
# pages' event frame.
class EventFormsTest < ActionDispatch::IntegrationTest
  include ActiveSupport::Testing::TimeHelpers

  def login_admin
    post "/login/validate", params: { username: "administrator", password: "administrator1" }
  end

  def login_provider
    post "/login/validate", params: { username: "janedoe", password: "janedoe1" }
  end

  def saved_marker
    css_select("turbo-frame#event [data-event-saved]").first
  end

  test "the calendar pages carry the event modal shell and the reschedule link opens the appointment" do
    login_admin
    get "/calendar"
    assert_select "#event-modal turbo-frame#event:not([src])"
    assert_select "#appointments-modal", count: 0
    assert_select "script[src*='components/event_modal']"
    get "/calendar/reschedule/abc123def456"
    assert_select "#event-modal turbo-frame#event[src=?]", "/appointments/#{appointments(:upcoming).id}/edit"
    get "/appointments"
    assert_select "#event-modal turbo-frame#event"
  end

  test "new appointment form: defaults, preselection, services with durations and the customer list" do
    login_admin
    travel_to Time.zone.local(2026, 7, 20, 9, 7) do
      get "/appointments/new"
      assert_select "turbo-frame#event form#appointment-form[action='/appointments'][method=post][data-ask-notify]" do
        assert_select "#start-datetime[value='20/07/2026 9:15 am']"
        assert_select "#end-datetime[value='20/07/2026 10:15 am']" # the first listed service lasts an hour
        assert_select "#select-service[data-durations] option[value=?]", services(:haircut).id.to_s
        assert_select "#select-provider option[value=?][data-services]", users(:zane).id.to_s
        assert_select "#appointment-repeat .repeat-fields"
        assert_select "#existing-customers-list div[data-id=?][data-customer]", users(:jx).id.to_s
        assert_select "input[type=hidden][name='appointment[color]']"
        assert_select "#notify-users[type=hidden]"
      end
    end

    get "/appointments/new", params: { start: "2026-09-01 10:00:00", end: "2026-09-01 10:45:00",
                                       provider_id: users(:zane).id, service_id: services(:group_session).id }
    assert_select "#start-datetime[value='01/09/2026 10:00 am']"
    assert_select "#end-datetime[value='01/09/2026 10:45 am']"
    assert_select "#select-service option[selected][value=?]", services(:group_session).id.to_s
    assert_select "#select-provider option[selected][value=?]", users(:zane).id.to_s

    # A free slot passes only the start: the end follows the first listed service.
    get "/appointments/new", params: { start: "2026-09-01 10:00:00", provider_id: users(:zane).id }
    assert_select "#end-datetime[value='01/09/2026 11:00 am']"
  end

  test "edit form shows the record and its customer, no repeat fields" do
    login_admin
    get "/appointments/#{appointments(:upcoming).id}/edit"
    assert_select "form#appointment-form[action=?] input[name=_method][value=patch]", "/appointments/#{appointments(:upcoming).id}"
    assert_select "#start-datetime[value='20/07/2026 10:00 am']"
    assert_select "#customer-id[value=?]", users(:jx).id.to_s
    assert_select "#name[value=JX]"
    assert_select "#appointment-repeat", count: 0
    assert_select ".modal-title", text: I18n.t("ea.edit_appointment_title")
  end

  test "create with a typed time and an existing customer by email answers the saved marker" do
    login_admin
    post "/appointments", params: {
      notify_users: "0",
      appointment: { id_services: services(:haircut).id, id_users_provider: users(:zane).id, color: "#eb8687",
                     status: "Booked", start_datetime: "21/07/2026 2:00 pm", end_datetime: "21/07/2026 2:30 pm", notes: "Fringe" },
      customer: { name: "JX", email: "j@example.org", language: "english", timezone: "UTC" }
    }
    assert_response :success
    assert_equal I18n.t("ea.appointment_saved"), saved_marker["data-message"]
    appointment = Appointment.find_by!(notes: "Fringe")
    assert_equal users(:jx).id, appointment.id_users_customer
    assert_equal "2026-07-21 14:00", appointment.start_datetime.strftime("%F %H:%M")
    assert_equal "#eb8687", appointment.color
  end

  test "a clash re-renders the form with the message and a force save field; saving again forces" do
    login_admin
    clash = { id_services: services(:haircut).id, id_users_provider: users(:zane).id, status: "Booked",
              start_datetime: "2026-07-20 10:00:00", end_datetime: "2026-07-20 10:30:00", notes: "Clash" }
    post "/appointments", params: { notify_users: "0", appointment: clash, customer: { id: users(:jx).id, name: "JX" } }
    assert_response :unprocessable_entity
    assert_select "form#appointment-form .modal-message", text: I18n.t("ea.provider_has_conflicting_appointment")
    assert_select "#force-save[value='1']"
    assert_select "#appointment-notes", text: "Clash"
    assert_nil Appointment.find_by(notes: "Clash")

    post "/appointments", params: { notify_users: "0", force_save: "1", appointment: clash, customer: { id: users(:jx).id, name: "JX" } }
    assert_response :success
    assert saved_marker
    assert Appointment.find_by(notes: "Clash")
  end

  test "a repeat pattern books the series and reports skipped dates in the marker" do
    login_admin
    Setting.set("future_booking_limit", "40")
    travel_to Time.zone.local(2026, 7, 20, 8) do
      post "/appointments", params: {
        notify_users: "0",
        appointment: { id_services: services(:haircut).id, id_users_provider: users(:zane).id, status: "Booked",
                       start_datetime: "2026-07-21 10:00:00", end_datetime: "2026-07-21 10:30:00" },
        customer: { id: users(:jx).id, name: "JX" },
        repeat: { rule: { rule_type: "IceCube::WeeklyRule", interval: 1, validations: { day: [ 2 ] } }.to_json, ends: "after", count: 3 }
      }
      assert_response :success
      assert_equal 1, AppointmentSeries.count
      assert_equal [], JSON.parse(saved_marker["data-skipped"])
    end
  end

  test "the remove form cancels with a reason and the delete kind destroys" do
    login_admin
    appointment = appointments(:upcoming)
    get "/appointments/#{appointment.id}/remove", params: { kind: "cancel" }
    assert_select "form#appointment-remove-form[action=?]", "/appointments/#{appointment.id}/remove" do
      assert_select "input[name=kind][value=cancel]"
      assert_select "input[type=radio][name=notify_users][value='1'][checked]"
      assert_select "textarea#cancellation-reason"
      assert_select ".modal-title", text: I18n.t("ea.cancel_appointment_title")
    end

    post "/appointments/#{appointment.id}/remove", params: { kind: "cancel", notify_users: "0", cancellation_reason: "Away" }
    assert_response :success
    assert saved_marker
    assert_equal "cancelled", appointment.reload.appointment_status.kind
    assert_includes appointment.notes, "Away"

    post "/appointments/#{appointment.id}/remove", params: { kind: "delete", notify_users: "0" }
    assert_not Appointment.exists?(appointment.id)
  end

  test "unavailability form round trip and delete" do
    login_admin
    get "/unavailabilities/new", params: { provider_id: users(:zane).id, start: "2026-07-22 12:00:00", end: "2026-07-22 13:00:00" }
    assert_select "form#unavailability-form[action='/unavailabilities']"
    assert_select "#unavailability-provider option[selected][value=?]", users(:zane).id.to_s
    assert_select "#unavailability-start[value='22/07/2026 12:00 pm']"

    post "/unavailabilities", params: { unavailability: { id_users_provider: users(:zane).id, start_datetime: "22/07/2026 12:00 pm",
                                                          end_datetime: "22/07/2026 1:00 pm", notes: "Dentist" } }
    assert_response :success
    assert_equal I18n.t("ea.unavailability_saved"), saved_marker["data-message"]
    block = Appointment.unavailabilities.find_by!(notes: "Dentist")
    assert_equal "2026-07-22 13:00", block.end_datetime.strftime("%F %H:%M")

    get "/unavailabilities/#{block.id}/edit"
    assert_select "form#unavailability-form[action=?]", "/unavailabilities/#{block.id}"
    patch "/unavailabilities/#{block.id}", params: { unavailability: { id_users_provider: users(:zane).id, start_datetime: "2026-07-22 12:00:00",
                                                                        end_datetime: "2026-07-22 14:00:00", notes: "Dentist" } }
    assert_equal "2026-07-22 14:00", block.reload.end_datetime.strftime("%F %H:%M")

    delete "/unavailabilities/#{block.id}"
    assert_response :success
    assert_not Appointment.exists?(block.id)
  end

  test "an unparseable time re-renders the form; another provider's event is forbidden" do
    login_admin
    post "/unavailabilities", params: { unavailability: { id_users_provider: users(:zane).id, start_datetime: "yesterday", end_datetime: "later" } }
    assert_response :unprocessable_entity
    assert_select "form#unavailability-form .modal-message", text: "yesterday: #{I18n.t('ea.invalid_datetime')}"
    I18n.available_locales.each do |locale|
      assert I18n.t("ea.invalid_datetime", locale: locale, fallback: false, default: nil).present?, "missing in #{locale}"
    end

    login_provider
    other = User.create!(name: "Other", email: "other@example.org", role: users(:zane).role)
    post "/unavailabilities", params: { unavailability: { id_users_provider: other.id, start_datetime: "2026-07-22 12:00:00", end_datetime: "2026-07-22 13:00:00" } }
    assert_response :forbidden
    get "/appointments/#{appointments(:upcoming).id}/edit"
    assert_response :success
  end
end
