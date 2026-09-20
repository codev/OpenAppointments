require "test_helper"

class AppointmentSeriesIntegrationTest < ActionDispatch::IntegrationTest
  include ActiveSupport::Testing::TimeHelpers

  def login_admin
    post "/login/validate", params: { username: "administrator", password: "administrator1" }
  end

  def login_provider
    post "/login/validate", params: { username: "janedoe", password: "janedoe1" }
  end

  setup do
    Setting.set("future_booking_limit", "40")
    Appointment.delete_all
    travel_to Time.new(2026, 7, 20, 8, 0, 0)
  end

  def weekly
    { rule_type: "IceCube::WeeklyRule", interval: 1, validations: { day: [ 1 ] } }
  end

  def save_repeating(repeat)
    post "/calendar/save_appointment", params: {
      appointment_data: {
        id_services: services(:haircut).id, id_users_provider: users(:zane).id, id_users_customer: users(:jx).id,
        start_datetime: "2026-07-20 10:00:00", end_datetime: "2026-07-20 10:30:00", status: "Booked",
        notes: "", location: "", color: "#7cbae8", is_unavailability: 0
      },
      repeat: repeat, notify_users: 0
    }
    response.parsed_body
  end

  test "saving with a repeat pattern books the series and reports skipped dates" do
    login_admin
    Appointment.create!(provider: users(:zane), customer: users(:jx), service: services(:haircut),
                        start_datetime: Time.new(2026, 7, 27, 10, 0), end_datetime: Time.new(2026, 7, 27, 10, 30))

    body = save_repeating({ rule: weekly.to_json, ends: "never" })
    assert_equal true, body["success"]
    assert_equal [ [ "2026-07-27", "busy" ] ], body["skipped"].map { |s| [ s["date"], s["reason"] ] }

    series = AppointmentSeries.sole
    assert_equal 5, series.appointments.count, "20 Jul plus 4 more Mondays within 40 days, 27 Jul skipped"
    assert_equal Date.new(2026, 7, 20), series.appointments.order(:occurrence_at).first.occurrence_at

    get "/appointment_series", as: :json
    row = response.parsed_body.sole
    assert_match "Weekly", row["description"]
    assert_equal 1, row["skipped"].size
    assert_includes row["booked"], "2026-08-03"
  end

  test "deleting one occurrence never recreates it" do
    login_admin
    save_repeating({ rule: weekly.to_json, ends: "never" })
    series = AppointmentSeries.sole
    victim = series.appointments.find_by(occurrence_at: Date.new(2026, 8, 3))

    post "/calendar/delete_appointment", params: { appointment_id: victim.id, notify_users: 0 }
    assert_equal true, response.parsed_body["success"]
    assert_includes series.reload.removed_list, "2026-08-03"
    assert_empty series.materialise[:created]
  end

  test "cancel from a date and reschedule the pattern" do
    login_admin
    save_repeating({ rule: weekly.to_json, ends: "never" })
    series = AppointmentSeries.sole

    post "/appointment_series/#{series.id}/reschedule",
         params: { repeat: { rule: { rule_type: "IceCube::WeeklyRule", interval: 1, validations: { day: [ 2 ] } }.to_json, ends: "after", count: 2 } }
    assert_equal true, response.parsed_body["success"]
    assert series.reload.appointments.where("occurrence_at > ?", Date.new(2026, 7, 20)).all? { |a| a.occurrence_at.tuesday? }

    post "/appointment_series/#{series.id}/cancel", params: { from: "2026-07-21", notify_users: 0 }, as: :json
    assert_equal true, response.parsed_body["success"]
    assert_equal [ Date.new(2026, 7, 20) ], series.reload.appointments.active.pluck(:occurrence_at)
    assert_equal Date.new(2026, 7, 20), series.ends_on
  end

  test "a provider only sees and changes their own series" do
    login_admin
    save_repeating({ rule: weekly.to_json, ends: "never" })
    other = User.create!(name: "Other", email: "other@example.org", role: users(:zane).role)
    other.create_settings!(username: "other", password: Passwords.hash("otherother1"), working_plan: users(:zane).settings.working_plan)
    ServiceProviderLink.create!(id_users: other.id, id_services: services(:haircut).id)
    foreign = AppointmentSeries.create!(provider: other, customer: users(:jx), service: services(:haircut),
                                        ice_schedule: AppointmentSeries.schedule_from({ "rule" => { "rule_type" => "IceCube::DailyRule", "interval" => 1 }.to_json }, Date.new(2026, 7, 20)),
                                        starts_on: Date.new(2026, 7, 20), start_time: "12:00", duration: 30)

    login_provider
    get "/appointment_series", as: :json
    assert_equal [ users(:zane).id ], response.parsed_body.map { |row| row["id_users_provider"] }.uniq

    post "/appointment_series/#{foreign.id}/cancel", params: { from: "2026-07-21" }, as: :json
    assert_equal false, response.parsed_body["success"]
  end

  test "the recurring_select dialog can ask the server for a rule summary" do
    login_admin
    post "/recurring_select/translate/en", params: { rule_type: "IceCube::WeeklyRule", interval: 1, validations: { day: [ 1, 3 ] } }
    assert_response :success
    assert_equal "Weekly on Mondays and Wednesdays", response.body
  end

  test "the email context carries the repeat description and next date" do
    login_admin
    save_repeating({ rule: weekly.to_json, ends: "never" })
    first = AppointmentSeries.sole.appointments.order(:occurrence_at).first
    context = Messaging::Template.appointment_context(appointment: first, service: first.service,
                                                      provider: first.provider, customer: first.customer)
    assert_match "Weekly on Mondays", context["Repeats"]
    assert context["Next Appointment"].present?
  end
end

# The series panel as Rails views in the appointments page frame.
class AppointmentSeriesPanelTest < ActionDispatch::IntegrationTest
  include ActiveSupport::Testing::TimeHelpers

  setup do
    Setting.set("future_booking_limit", "40")
    travel_to Time.new(2026, 7, 20, 8, 0, 0)
    repeat = { "rule" => { rule_type: "IceCube::WeeklyRule", interval: 1, validations: { day: [ 1 ] } }.to_json, "ends" => "never" }
    @series = AppointmentSeries.start_from(appointments(:upcoming), repeat)[:series]
    post "/login/validate", params: { username: "administrator", password: "administrator1" }
  end

  test "the appointments page embeds the lazy series frame and the list renders into it" do
    get "/appointments"
    assert_select "#series-view turbo-frame#series[src='/appointment_series'][loading=lazy]"
    assert_select "#series-pattern-modal"
    assert_select "#series-cancel-modal", count: 0

    get "/appointment_series"
    assert_select "turbo-frame#series #series-table tbody tr[data-id=?][data-rule]", @series.id.to_s do
      assert_select "td", text: "Zane"
      assert_select "td", text: /20\/07\/2026/
      assert_select "a.series-cancel[href=?]", "/appointment_series/#{@series.id}/cancel"
      assert_select "button.series-edit[data-id=?]", @series.id.to_s
    end

    get "/appointment_series", as: :json
    assert_equal [ @series.id ], response.parsed_body.map { |row| row["id"] }
  end

  test "the cancel form lists the booked dates and cancelling returns to the list with a flash" do
    get "/appointment_series/#{@series.id}/cancel"
    assert_select "turbo-frame#series form#series-cancel-form[action=?]", "/appointment_series/#{@series.id}/cancel" do
      assert_select "#series-cancel-dates input[type=radio][name=from][value='2026-07-20'][checked]"
      assert_select "#series-cancel-dates input[type=radio][name=from][value='2026-08-03']"
      assert_select "textarea#series-cancel-reason"
      assert_select "input#series-cancel-notify[checked]"
      assert_select "a[href='/appointment_series']", text: I18n.t("ea.close")
    end

    post "/appointment_series/#{@series.id}/cancel", params: { from: "2026-07-27", notify_users: "0", cancellation_reason: "Away" }
    assert_redirected_to "/appointment_series"
    follow_redirect!
    assert_select ".notice[data-tone=success]", text: I18n.t("ea.series_cancelled")
    assert_equal [ Date.new(2026, 7, 20) ], @series.reload.appointments.active.pluck(:occurrence_at)
    assert_select "#series-table tbody tr", count: 1

    post "/appointment_series/#{@series.id}/cancel", params: { from: "not a date" }
    assert_redirected_to "/appointment_series"
    follow_redirect!
    assert_select ".notice[data-tone=error]"
  end

  test "providers only get their own series in the panel and cannot cancel others" do
    foreign_provider = User.create!(name: "Other", email: "other@example.org", role: users(:zane).role)
    foreign = AppointmentSeries.create!(id_users_provider: foreign_provider.id, id_users_customer: users(:jx).id,
                                        id_services: services(:haircut).id, ice_schedule: @series.ice_schedule,
                                        starts_on: Date.new(2026, 7, 21), start_time: "11:00", duration: 30)
    post "/login/validate", params: { username: "janedoe", password: "janedoe1" }
    get "/appointment_series"
    assert_select "#series-table tbody tr", count: 1
    get "/appointment_series/#{foreign.id}/cancel"
    assert_response :not_found
  end
end
