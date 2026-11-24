require "test_helper"

# The Free page: the List page's free rows alone, for every date in the booking
# window, admins only.
class FreePageTest < ActionDispatch::IntegrationTest
  def login_admin
    post "/login/validate", params: { username: "administrator", password: "administrator1" }
  end

  def login_provider
    post "/login/validate", params: { username: "janedoe", password: "janedoe1" }
  end

  # Sunday 19 July 2026 noon: Zane works Monday to Friday except Wednesday.
  def on_the_sunday(&block) = travel_to(Time.new(2026, 7, 19, 12, 0, 0), &block)

  test "an admin sees free slots alone, grouped by date and stylist, across the booking window" do
    Setting.set("future_booking_limit", "4")
    login_admin
    on_the_sunday do
      get "/free"
      assert_response :success
      assert_select "#calendar-page turbo-frame#day_view form#day-filter[action='/free']"
      assert_select "#header .nav-item a[href='/free']", text: /Free/
      # Sunday to Thursday; today (Sunday) and Wednesday are days off, so Monday, Tuesday and Thursday remain.
      assert_select ".date-column", count: 3
      assert_select ".date-column h5", text: "20/07/2026"
      assert_select ".date-column h5", text: "21/07/2026"
      assert_select ".date-column h5", text: "22/07/2026", count: 0
      assert_select ".date-column h5", text: "23/07/2026"
      assert_select ".provider-column[data-provider-id=?] h6", users(:zane).id.to_s, text: "Zane"
      assert_select ".day-entry-free[href*='provider_id=#{users(:zane).id}'][href*='start=2026-07-20+09%3A00%3A00']"
      assert_select ".day-entry-appointment", count: 0
      assert_select ".day-entry-unavailability", count: 0
      assert_select ".day-entry-break", count: 0
    end
  end

  test "a stylist booked solid all day is left out of that date" do
    Setting.set("future_booking_limit", "1")
    Appointment.create!(provider: users(:zane), customer: users(:jx), service: services(:haircut),
                        start_datetime: "2026-07-20 09:00:00", end_datetime: "2026-07-20 18:00:00")
    login_admin
    on_the_sunday do
      get "/free"
      assert_select ".date-column", count: 0
      assert_select "#free-empty", count: 1
    end
  end

  test "the stylist filter narrows the columns and is URL state" do
    Setting.set("future_booking_limit", "1")
    login_admin
    on_the_sunday do
      get "/free", params: { providers: [ "" ] }
      assert_select ".provider-column", count: 0
      get "/free", params: { providers: [ users(:zane).id ] }
      assert_select ".provider-column[data-provider-id=?]", users(:zane).id.to_s
      assert_select "#provider-filter input[value=?][checked]", users(:zane).id.to_s
    end
  end

  test "a stylist gets 403 and no header item" do
    login_provider
    get "/free"
    assert_response :forbidden
    get "/appointments"
    assert_select "#header .nav-item a[href='/free']", count: 0
  end
end
