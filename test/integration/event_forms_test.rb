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
        assert_select "#appointment-duration[type=number][name='appointment[duration]'][min='5'][required][value='60']" # the first listed service lasts an hour
        assert_select "label[for=appointment-duration]", text: I18n.t("ea.duration_minutes")
        assert_select "#end-datetime", count: 0
        assert_select "#select-service[data-durations] option[value=?]", services(:haircut).id.to_s
        assert_select "#select-provider option[value=?][data-services]", users(:zane).id.to_s
        assert_select "#appointment-repeat .repeat-fields"
        assert_select "#existing-customers-list div[data-id=?][data-customer]", users(:jx).id.to_s
        assert_select "[name='appointment[color]'], .color-selection, #select-service[data-colors]", count: 0
        assert_select "#notify-users[type=hidden]"
      end
    end

    get "/appointments/new", params: { start: "2026-09-01 10:00:00", end: "2026-09-01 10:45:00",
                                       provider_id: users(:zane).id, service_id: services(:group_session).id }
    assert_select "#start-datetime[value='01/09/2026 10:00 am']"
    assert_select "#appointment-duration[value='45']"
    assert_select "#select-service option[selected][value=?]", services(:group_session).id.to_s
    assert_select "#select-provider option[selected][value=?]", users(:zane).id.to_s

    # A free slot passes only the start: the duration follows the first listed service.
    get "/appointments/new", params: { start: "2026-09-01 10:00:00", provider_id: users(:zane).id }
    assert_select "#appointment-duration[value='60']"
  end

  test "the location field shows only when appointments include locations" do
    login_admin
    get "/appointments/new"
    assert_select "#appointment-location", count: 0

    Setting.set("appointments_include_locations", "1")
    get "/appointments/new"
    assert_select "input#appointment-location[name='appointment[location]']"
  ensure
    Setting.set("appointments_include_locations", "0")
  end

  test "the meeting link field shows only when appointments include meeting links" do
    login_admin
    get "/appointments/new"
    assert_select "#appointment-meeting-link", count: 0

    Setting.set("appointments_include_meeting_links", "1")
    get "/appointments/new"
    assert_select "input#appointment-meeting-link[name='appointment[meeting_link]']"
  ensure
    Setting.set("appointments_include_meeting_links", "0")
  end

  test "booking settings offer the meeting links switch, off by default, below the locations switch" do
    login_admin
    get "/booking_settings"
    assert_select "input[type=checkbox][name='settings[appointments_include_meeting_links]']:not([checked])"
    names = css_select("input[type=checkbox][name^='settings[']").map { |box| box["name"] }
    assert_equal names.index("settings[appointments_include_locations]") + 1, names.index("settings[appointments_include_meeting_links]")
  end

  test "booking settings offer the locations switch, off by default, between Any provider and Provider first" do
    login_admin
    get "/booking_settings"
    assert_select "input[type=checkbox][name='settings[appointments_include_locations]']:not([checked])"
    names = css_select("input[type=checkbox][name^='settings[']").map { |box| box["name"] }
    assert_operator names.index("settings[display_any_provider]"), :<, names.index("settings[appointments_include_locations]")
    assert_operator names.index("settings[appointments_include_locations]"), :<, names.index("settings[booking_provider_first]")
  end

  test "services hidden from the public, such as a meeting, are bookable by staff in their own group" do
    meeting = Service.create!(name: "Meeting", duration: 60, is_private: true)
    ServiceProviderLink.create!(id_users: users(:zane).id, id_services: meeting.id)
    login_admin
    get "/appointments/new"
    assert_select "#select-service optgroup[label='Hidden From Public'] option[value=?]", meeting.id.to_s, text: "Meeting"
    get "/appointments", params: { date: "2026-07-20" }
    assert_select "#service-filter input[value=?]", meeting.id.to_s
  end

  test "edit form shows the record and its customer, no repeat fields" do
    login_admin
    get "/appointments/#{appointments(:upcoming).id}/edit"
    assert_select "form#appointment-form[action=?] input[name=_method][value=patch]", "/appointments/#{appointments(:upcoming).id}"
    assert_select "#start-datetime[value='20/07/2026 10:00 am']"
    assert_select "#appointment-duration[value=?]", appointments(:upcoming).duration_minutes.to_s
    assert_select "#customer-id[value=?]", users(:jx).id.to_s
    assert_select "#name[value=JX]"
    assert_select "#appointment-repeat", count: 0
    assert_select ".modal-title", text: I18n.t("ea.edit_appointment_title")
  end

  test "create with a typed time and an existing customer by email answers the saved marker" do
    login_admin
    post "/appointments", params: {
      notify_users: "0",
      appointment: { id_services: services(:haircut).id, id_users_provider: users(:zane).id,
                     status: "Booked", start_datetime: "21/07/2026 2:00 pm", duration: "45", notes: "Fringe" },
      customer: { name: "JX", email: "j@example.org", language: "english", timezone: "UTC" }
    }
    assert_response :success
    assert_equal I18n.t("ea.appointment_saved"), saved_marker["data-message"]
    appointment = Appointment.find_by!(notes: "Fringe")
    assert_equal users(:jx).id, appointment.id_users_customer
    assert_equal "2026-07-21 14:00", appointment.start_datetime.strftime("%F %H:%M")
    assert_equal "2026-07-21 14:45", appointment.end_datetime.strftime("%F %H:%M")
  end

  test "a zero duration re-renders the form with the message and the typed duration" do
    login_admin
    assert_no_difference "Appointment.appointments.count" do
      post "/appointments", params: {
        notify_users: "0",
        appointment: { id_services: services(:haircut).id, id_users_provider: users(:zane).id, status: "Booked",
                       start_datetime: "21/07/2026 2:00 pm", duration: "0", notes: "Zero" },
        customer: { id: users(:jx).id, name: "JX" }
      }
    end
    assert_response :unprocessable_entity
    assert_select "form#appointment-form .modal-message", text: /after start/
    assert_select "#appointment-duration[value='0']"
    assert_select "#appointment-notes", text: "Zero"
  end

  test "an unreadable start keeps the typed duration in the re-rendered form" do
    login_admin
    post "/appointments", params: {
      notify_users: "0",
      appointment: { id_services: services(:haircut).id, id_users_provider: users(:zane).id, status: "Booked",
                     start_datetime: "soon", duration: "40" },
      customer: { id: users(:jx).id, name: "JX" }
    }
    assert_response :unprocessable_entity
    assert_select "#appointment-duration[value='40']"
  end

  test "a clash re-renders the form with the message and a force save field; saving again forces" do
    login_admin
    clash = { id_services: services(:haircut).id, id_users_provider: users(:zane).id, status: "Booked",
              start_datetime: "2026-07-20 10:00:00", duration: "30", notes: "Clash" }
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
                       start_datetime: "2026-07-21 10:00:00", duration: "30" },
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

  test "a stylist cancels an appointment but cannot delete it" do
    login_provider
    appointment = appointments(:upcoming)
    get "/appointments/#{appointment.id}/remove", params: { kind: "delete" }
    assert_response :forbidden
    get "/appointments/#{appointment.id}/remove", params: { kind: "cancel" }
    assert_response :success

    post "/appointments/#{appointment.id}/remove", params: { kind: "delete", notify_users: "0" }
    assert_response :unprocessable_entity
    assert Appointment.exists?(appointment.id)
    assert_select "#appointment-remove-form .alert-danger", text: /permissions/

    post "/appointments/#{appointment.id}/remove", params: { kind: "cancel", notify_users: "0", cancellation_reason: "Away" }
    assert_response :success
    assert_equal "cancelled", appointment.reload.appointment_status.kind
  end

  test "a new unavailability defaults to the next hour on the default zone's clock" do
    Setting.set("default_timezone", "Europe/London")
    saved = ENV["TZ"]
    ENV["TZ"] = "UTC"
    login_admin
    travel_to Time.utc(2026, 8, 1, 12, 5) do
      get "/unavailabilities/new", params: { provider_id: users(:zane).id }
      assert_response :success
      value = css_select("#unavailability-start").first["value"]
      assert_match(/14:00|2:00 pm/i, value, "expected the London hour after 13:05, got #{value}")
    end
  ensure
    saved.nil? ? ENV.delete("TZ") : ENV["TZ"] = saved
  end

  test "unavailability form round trip and delete" do
    login_admin
    get "/unavailabilities/new", params: { provider_id: users(:zane).id, start: "2026-07-22 12:00:00", end: "2026-07-22 13:00:00" }
    assert_select "form#unavailability-form[action='/unavailabilities']"
    # Zane is the only stylist offering a service, so the form names them without a tick list.
    assert_select "#unavailability-providers input[type=hidden][value=?]", users(:zane).id.to_s
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

  def linked_provider(name)
    provider = User.create!(name: name, email: "#{name.downcase}@example.org", role: users(:zane).role)
    ServiceProviderLink.create!(id_users: provider.id, id_services: services(:haircut).id)
    provider
  end

  test "the busy time form offers a type and, to an admin, a stylist tick list" do
    linked_provider("Other")
    login_admin
    get "/unavailabilities/new", params: { provider_id: users(:zane).id }
    assert_select "label[for=unavailability-type]", text: "Type"
    assert_select "#unavailability-type option[value='']", text: "No type"
    assert_select "#unavailability-type option", text: "Meeting"
    assert_select "#unavailability-providers .form-check", count: 2
    assert_select "#unavailability-providers input[type=checkbox][name='unavailability[provider_ids][]'][value=?][checked]", users(:zane).id.to_s
    assert_select "#unavailability-providers input[type=checkbox]:not([checked])", count: 1
    assert_select "#unavailability-providers + .form-text", text: /Tick everyone/
    assert_select "#delete-unavailability", count: 0
  end

  test "a stylist's busy time form names only themselves" do
    linked_provider("Other")
    login_provider
    get "/unavailabilities/new"
    assert_select "#unavailability-providers input[type=hidden][name='unavailability[provider_ids][]'][value=?]", users(:zane).id.to_s
    assert_select "#unavailability-providers input[type=checkbox]", count: 0
    assert_select "#unavailability-providers", text: /Zane/
  end

  test "one busy time for several stylists is a row each in one group, edited and deleted together" do
    other = linked_provider("Other")
    third = linked_provider("Third")
    login_admin
    post "/unavailabilities", params: { unavailability: { provider_ids: [ users(:zane).id, other.id ], unavailability_type_id: unavailability_types(:meeting).id,
                                                          start_datetime: "22/07/2026 12:00 pm", end_datetime: "22/07/2026 1:00 pm", notes: "Team" } }
    assert_response :success
    assert_equal I18n.t("ea.unavailability_saved"), saved_marker["data-message"]
    rows = Appointment.unavailabilities.where(notes: "Team")
    assert_equal [ other.id, users(:zane).id ].sort, rows.map(&:id_users_provider).sort
    assert_equal 1, rows.map(&:unavailability_group).uniq.compact.size
    assert rows.all? { |row| row.unavailability_type == unavailability_types(:meeting) }
    zane_row = rows.find_by!(id_users_provider: users(:zane).id)

    get "/unavailabilities/#{zane_row.id}/edit"
    assert_select "#unavailability-type option[selected]", text: "Meeting"
    assert_select "#unavailability-providers input[checked]", count: 2
    assert_select "button[form=delete-unavailability]", text: /Delete/
    assert_select "form#delete-unavailability[action=?][data-turbo-confirm=?]", "/unavailabilities/#{zane_row.id}",
                  I18n.t("ea.delete_unavailability_group").sub("{{count}}", "2")

    patch "/unavailabilities/#{zane_row.id}", params: { unavailability: { provider_ids: [ other.id, third.id ], unavailability_type_id: unavailability_types(:leave).id,
                                                                           start_datetime: "2026-07-22 12:00:00", end_datetime: "2026-07-22 14:00:00", notes: "Team" } }
    assert_response :success
    assert_not Appointment.exists?(zane_row.id)
    rows = Appointment.unavailabilities.where(notes: "Team")
    assert_equal [ other.id, third.id ].sort, rows.map(&:id_users_provider).sort
    assert_equal [ zane_row.unavailability_group ], rows.map(&:unavailability_group).uniq
    assert rows.all? { |row| row.end_datetime.strftime("%H:%M") == "14:00" && row.unavailability_type == unavailability_types(:leave) }

    delete "/unavailabilities/#{rows.first.id}"
    assert_response :success
    assert_empty Appointment.unavailabilities.where(notes: "Team")
  end

  test "a stylist editing or deleting a team busy time touches their own row only" do
    other = linked_provider("Other")
    group = SecureRandom.uuid
    mine = Appointment.create!(provider: users(:zane), is_unavailability: true, unavailability_group: group, notes: "Team",
                               start_datetime: "2026-07-22 12:00:00", end_datetime: "2026-07-22 13:00:00")
    theirs = Appointment.create!(provider: other, is_unavailability: true, unavailability_group: group, notes: "Team",
                                 start_datetime: "2026-07-22 12:00:00", end_datetime: "2026-07-22 13:00:00")
    login_provider
    get "/unavailabilities/#{mine.id}/edit"
    assert_select "#unavailability-providers input[type=hidden][value=?]", users(:zane).id.to_s
    assert_select "form#delete-unavailability[data-turbo-confirm=?]", I18n.t("ea.delete_record_prompt")

    patch "/unavailabilities/#{mine.id}", params: { unavailability: { provider_ids: [ users(:zane).id ], start_datetime: "2026-07-22 12:00:00",
                                                                       end_datetime: "2026-07-22 14:00:00", notes: "Team" } }
    assert_response :success
    assert_equal "14:00", mine.reload.end_datetime.strftime("%H:%M")
    assert_equal "13:00", theirs.reload.end_datetime.strftime("%H:%M")

    delete "/unavailabilities/#{mine.id}"
    assert_response :success
    assert_not Appointment.exists?(mine.id)
    assert Appointment.exists?(theirs.id)
  end

  test "a busy time with no stylist ticked re-renders the form" do
    login_admin
    post "/unavailabilities", params: { unavailability: { provider_ids: [ "" ], start_datetime: "2026-07-22 12:00:00", end_datetime: "2026-07-22 13:00:00" } }
    assert_response :unprocessable_entity
    assert_select "form#unavailability-form .modal-message"
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
  # The form's provider list follows the service, but a post can name any pair.
  test "saving an appointment refuses a provider who does not offer the service" do
    other = Service.create!(name: "Beard Trim", duration: 15)
    login_admin
    assert_no_difference "Appointment.appointments.count" do
      post "/appointments", params: {
        notify_users: "0",
        appointment: { id_services: other.id, id_users_provider: users(:zane).id, status: "Booked",
                       start_datetime: "21/07/2026 2:00 pm", duration: "15" },
        customer: { id: users(:jx).id, name: "JX" }
      }
    end
    assert_response :unprocessable_entity
    assert_select "form#appointment-form .modal-message", text: I18n.t("ea.provider_does_not_offer_service")

    post "/calendar/save_appointment", params: {
      appointment_data: { start_datetime: "2026-07-21 14:00:00", end_datetime: "2026-07-21 14:15:00",
                          id_users_provider: users(:zane).id, id_services: other.id, id_users_customer: users(:jx).id }
    }
    assert_equal false, response.parsed_body["success"]
    assert_equal I18n.t("ea.provider_does_not_offer_service"), response.parsed_body["message"]
  end
end
