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
    assert_select "#filter-provider option", count: 2
    assert_select ".provider-column[data-provider-id=?]", other.id.to_s, count: 0
  end
end
