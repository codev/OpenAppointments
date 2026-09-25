require "test_helper"

# The server rendered appointments page.
class AppointmentsPageTest < ActionDispatch::IntegrationTest
  def login_admin
    post "/login/validate", params: { username: "administrator", password: "administrator1" }
  end

  test "a working day lists the appointment, free gaps, a break-free morning and an unavailability" do
    login_admin
    get "/appointments", params: { date: "2026-07-20" }
    assert_response :success
    assert_select "turbo-frame#day_view form#day-filter[action='/appointments'][method=get]"
    assert_select ".date-column h5", text: "20/07/2026"
    assert_select ".provider-column[data-provider-id=?] h6", users(:zane).id.to_s, text: "Zane"
    assert_select ".day-entry-appointment[href=?]", "/appointments/#{appointments(:upcoming).id}/edit", text: /JX - Trim Cut/
    assert_select ".day-entry-appointment small", text: "10:00 am - 10:30 am"
    assert_select ".day-entry-unavailability[href=?]", "/unavailabilities/#{appointments(:lunch_block).id}/edit"
    assert_select ".day-entry-free[href^='/appointments/new?']", minimum: 2
    assert_select ".day-entry-free[href*='provider_id=#{users(:zane).id}'][href*='start=2026-07-20+09%3A00%3A00']"
    assert_select "a#next-day[href*='date=2026-07-21']"
    assert_select "a#previous-day[href*='date=2026-07-19']"
    assert_select "#not-working-notes div", count: 0
  end

  test "a day off lists the provider as not working; three days show three columns" do
    login_admin
    get "/appointments", params: { date: "2026-07-19" }
    assert_select ".provider-column", count: 0
    assert_select "#not-working-notes", text: /Not working 19\/07\/2026: Zane/

    get "/appointments", params: { date: "2026-07-20", days: 3 }
    assert_select ".date-column", count: 3
    assert_select "#select-day-interval option[selected][value='3']"
  end

  test "working stylists is the default and a stylist off all day by an unavailability is not working" do
    login_admin
    Appointment.create!(is_unavailability: true, provider: users(:zane), notes: "Holiday",
                        start_datetime: "2026-07-21 08:00:00", end_datetime: "2026-07-21 19:00:00")
    get "/appointments", params: { date: "2026-07-21" }
    assert_select "#filter-provider option:first-child[value='']", text: "Working Providers"
    assert_select "#filter-provider option[value=all]", text: "All Providers"
    assert_select ".provider-column", count: 0
    assert_select "#not-working-notes", text: /Not working 21\/07\/2026: Zane/
  end

  test "a stylist with an appointment on their day off still gets a column" do
    login_admin
    booked = Appointment.create!(provider: users(:zane), customer: users(:jx), service: services(:haircut),
                                 start_datetime: "2026-07-19 11:00:00", end_datetime: "2026-07-19 11:30:00")
    get "/appointments", params: { date: "2026-07-19" }
    assert_select ".provider-column[data-provider-id=?]", users(:zane).id.to_s
    assert_select ".day-entry-appointment[href=?]", "/appointments/#{booked.id}/edit"
    assert_select ".day-entry-free", count: 0
  end

  test "a stylist off sick all day with appointments shows both the appointment and the unavailability" do
    login_admin
    sick = Appointment.create!(is_unavailability: true, provider: users(:zane), notes: "Unwell",
                               start_datetime: "2026-07-20 08:00:00", end_datetime: "2026-07-20 19:00:00")
    get "/appointments", params: { date: "2026-07-20" }
    assert_select ".day-entry-appointment[href=?]", "/appointments/#{appointments(:upcoming).id}/edit"
    assert_select ".day-entry-unavailability[href=?]", "/unavailabilities/#{sick.id}/edit"
  end

  test "all stylists gives every stylist a column, working or not, and the day links keep the choice" do
    login_admin
    get "/appointments", params: { date: "2026-07-19", provider: "all" }
    assert_select ".provider-column[data-provider-id=?]", users(:zane).id.to_s
    assert_select "#not-working-notes div", count: 0
    assert_select "#filter-provider option[selected][value=all]"
    assert_select "a#next-day[href*='provider=all']"
  end

  test "filters narrow the entries and statuses default to the non cancelled kinds" do
    login_admin
    get "/appointments", params: { date: "2026-07-20", service: services(:group_session).id }
    assert_select ".day-entry-appointment", count: 0
    assert_select "#filter-service option[selected][value=?]", services(:group_session).id.to_s

    get "/appointments", params: { date: "2026-07-20", statuses: [ "Confirmed" ] }
    assert_select ".day-entry-appointment", count: 0
    assert_select "#status-filter input[value=Booked]:not([checked])"

    get "/appointments", params: { date: "2026-07-20" }
    assert_select "#status-filter input[value=Booked][checked]"
    assert_select "#status-filter input[value=Cancelled]:not([checked])"
  end

  test "an unparseable date falls back to today and a provider sees only their own column" do
    login_admin
    get "/appointments", params: { date: "nonsense" }
    assert_response :success
    assert_select "#select-date[value=?]", Date.current.to_s

    post "/login/validate", params: { username: "janedoe", password: "janedoe1" }
    other = User.create!(name: "Other", email: "other@example.org", role: users(:zane).role)
    get "/appointments", params: { date: "2026-07-20" }
    assert_select "#filter-provider option", count: 3
    assert_select ".provider-column[data-provider-id=?]", other.id.to_s, count: 0
  end
  # A free slot click names the provider; the form must open on a service that
  # provider offers, or the provider list (which follows the service) drops them.
  test "a new appointment for a provider opens on a service they offer" do
    riley = User.create!(name: "Riley", email: "riley@example.org", role: Role.find_by!(slug: Role::PROVIDER))
    riley.create_settings!(username: "riley", password: Passwords.hash("rileypass1"), working_plan: users(:zane).settings.working_plan)
    aardvark = Service.create!(name: "Aardvark Wash", duration: 15)
    ServiceProviderLink.create!(provider: riley, service: aardvark)
    login_admin
    get "/appointments/new", params: { start: "2026-07-20 11:30:00", provider_id: users(:zane).id }
    assert_response :success
    assert_select "#select-service option[value=?]", aardvark.id.to_s
    assert_select "#select-provider option[selected][value=?]", users(:zane).id.to_s
    # Zane's first service in list order, not the list's first service.
    assert_select "#select-service option[selected][value=?]", services(:group_session).id.to_s
    assert_select "#select-service option[selected]", count: 1
  end

  test "the 2.3.0 strings exist in every locale" do
    keys = %w[working_providers hidden_from_public slot_interval_hint messages_both_channels]
    I18n.available_locales.each do |locale|
      keys.each do |key|
        assert I18n.t("ea.#{key}", locale: locale, fallback: false, default: nil).present?, "missing ea.#{key} in #{locale}"
      end
    end
  end
end
