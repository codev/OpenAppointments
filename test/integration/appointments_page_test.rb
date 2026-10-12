require "test_helper"

# The server rendered appointments page.
class AppointmentsPageTest < ActionDispatch::IntegrationTest
  def login_admin
    post "/login/validate", params: { username: "administrator", password: "administrator1" }
  end

  # Ids of the records behind the page's entries of one kind (from their popover data).
  def entry_ids(kind)
    css_select("button.day-entry-#{kind}[data-event]").map { |entry| JSON.parse(entry["data-event"])["id"] }
  end

  test "a working day lists the appointment, free gaps, a break-free morning and an unavailability" do
    login_admin
    get "/appointments", params: { date: "2026-07-20" }
    assert_response :success
    assert_select "turbo-frame#day_view form#day-filter[action='/appointments'][method=get]"
    assert_select ".date-column h5", text: "20/07/2026"
    assert_select ".provider-column[data-provider-id=?] h6", users(:zane).id.to_s, text: "Zane"
    # Appointments and unavailabilities open the calendar's details popover from the same data.
    entry = css_select("button.day-entry-appointment[data-event]").first
    assert_match(/JX - Trim Cut/, entry.text)
    event = JSON.parse(entry["data-event"])
    assert_equal appointments(:upcoming).id, event["id"]
    assert_equal "JX", event.dig("customer", "name")
    assert_equal "Zane", event.dig("provider", "name")
    assert event["customer"].key?("unread_messages")
    assert_select ".day-entry-appointment small", text: "10:00 am - 10:30 am"
    unavailability = JSON.parse(css_select("button.day-entry-unavailability[data-event]").first["data-event"])
    assert_equal appointments(:lunch_block).id, unavailability["id"]
    assert unavailability["is_unavailability"]
    assert_select ".day-entry-free[href^='/appointments/new?']", minimum: 2
    assert_select ".day-entry-free[href*='provider_id=#{users(:zane).id}'][href*='start=2026-07-20+09%3A00%3A00']"
    assert_select "a#next-day[href*='date=2026-07-21']"
    assert_select "a#previous-day[href*='date=2026-07-19']"
    assert_select "#not-working-notes div", count: 0
  end

  test "a day off lists the provider as not working; three or seven days show that many columns" do
    login_admin
    get "/appointments", params: { date: "2026-07-19" }
    assert_select ".provider-column", count: 0
    assert_select "#not-working-notes", text: /Not working 19\/07\/2026: Zane/

    get "/appointments", params: { date: "2026-07-20", days: 3 }
    assert_select ".date-column", count: 3
    assert_select "#select-day-interval option[selected][value='3']"

    get "/appointments", params: { date: "2026-07-20", days: 7 }
    assert_select ".date-column", count: 7
    assert_select "#select-day-interval option[selected][value='7']", text: "7 Days"
  end

  # A page's scripts arrive in head order on a Turbo visit and a component
  # initialises as soon as its script runs, so a dependency must come first.
  test "the working plan exception dialog script follows utils/ui on the List and the Calendar" do
    login_admin
    %w[/appointments /calendar].each do |path|
      get path
      sources = css_select("head script[src]").map { |script| script["src"] }
      ui = sources.index { |src| src.include?("utils/ui") }
      modal = sources.index { |src| src.include?("components/working_plan_exceptions_modal") }
      assert ui && modal && ui < modal, "#{path}: expected utils/ui before the dialog script, got #{sources.inspect}"
    end
  end

  test "the List and the Calendar are never shown from a stale Turbo preview" do
    login_admin
    %w[/appointments /calendar].each do |path|
      get path
      assert_select "head meta[name=turbo-cache-control][content=no-preview]", 1, "expected the meta on #{path}"
    end
  end

  test "working stylists is the default and a stylist off all day by an unavailability is not working" do
    login_admin
    Appointment.create!(is_unavailability: true, provider: users(:zane), notes: "Holiday",
                        start_datetime: "2026-07-21 08:00:00", end_datetime: "2026-07-21 19:00:00")
    get "/appointments", params: { date: "2026-07-21" }
    assert_select "#provider-filter .dropdown-toggle", text: "Providers"
    assert_select "#provider-filter button[data-tick=all]", text: "All Providers"
    assert_select "#provider-filter button[data-tick=clear]", text: "Clear Providers"
    assert_select "#provider-filter input[data-tick=working][name='providers[]'][value=working][checked]"
    assert_select "#provider-filter label", text: /Working Providers/
    assert_select "#provider-filter input[name='providers[]'][value=?]:not([checked])", users(:zane).id.to_s
    assert_select ".provider-column", count: 0
    assert_select "#not-working-notes", text: /Not working 21\/07\/2026: Zane/
  end

  test "a stylist with an appointment on their day off still gets a column" do
    login_admin
    booked = Appointment.create!(provider: users(:zane), customer: users(:jx), service: services(:haircut),
                                 start_datetime: "2026-07-19 11:00:00", end_datetime: "2026-07-19 11:30:00")
    get "/appointments", params: { date: "2026-07-19" }
    assert_select ".provider-column[data-provider-id=?]", users(:zane).id.to_s
    assert_includes entry_ids("appointment"), booked.id
    assert_select ".day-entry-free", count: 0
  end

  test "a stylist off sick all day with appointments shows both the appointment and the unavailability" do
    login_admin
    sick = Appointment.create!(is_unavailability: true, provider: users(:zane), notes: "Unwell",
                               start_datetime: "2026-07-20 08:00:00", end_datetime: "2026-07-20 19:00:00")
    get "/appointments", params: { date: "2026-07-20" }
    assert_includes entry_ids("appointment"), appointments(:upcoming).id
    assert_includes entry_ids("unavailability"), sick.id
  end

  test "ticked stylists get a column, working or not, and the day links keep the choice" do
    login_admin
    get "/appointments", params: { date: "2026-07-19", providers: [ "", users(:zane).id ] }
    assert_select ".provider-column[data-provider-id=?]", users(:zane).id.to_s
    assert_select "#not-working-notes div", count: 0
    assert_select "#provider-filter input[value=?][checked]", users(:zane).id.to_s
    assert_select "#provider-filter input[data-tick=working]:not([checked])"
    assert_select "a#next-day[href*=?]", "providers%5B%5D=#{users(:zane).id}"
  end

  test "no stylists ticked shows no columns and says how many are ticked" do
    login_admin
    get "/appointments", params: { date: "2026-07-20", providers: [ "" ] }
    assert_select ".provider-column", count: 0
    assert_select "#not-working-notes div", count: 0
    assert_select "#provider-filter .dropdown-toggle", text: "Providers (0)"
    assert_select "#provider-filter input[type=hidden][name='providers[]'][value='']"
    assert_select "a#next-day[href*=?]", "providers%5B%5D="
  end

  test "services default to all ticked; ticked services narrow the entries and none ticked shows none" do
    login_admin
    get "/appointments", params: { date: "2026-07-20" }
    assert_select "#service-filter .dropdown-toggle", text: "Services"
    assert_select "#service-filter button[data-tick=all]", text: "All Services"
    assert_select "#service-filter button[data-tick=clear]", text: "Clear Services"
    assert_select "#service-filter input[data-tick=working]", count: 0
    assert_select "#service-filter input[name='services[]'][value=?][checked]", services(:haircut).id.to_s
    assert_select ".day-entry-appointment", minimum: 1

    get "/appointments", params: { date: "2026-07-20", services: [ "", services(:group_session).id ] }
    assert_select ".day-entry-appointment", count: 0
    assert_select "#service-filter input[value=?][checked]", services(:group_session).id.to_s
    assert_select "#service-filter input[value=?]:not([checked])", services(:haircut).id.to_s
    assert_select "#service-filter .dropdown-toggle", text: "Services (1)"
    assert_select "a#next-day[href*=?]", "services%5B%5D=#{services(:group_session).id}"

    get "/appointments", params: { date: "2026-07-20", services: [ "" ] }
    assert_select ".day-entry-appointment", count: 0
    assert_select ".provider-column[data-provider-id=?]", users(:zane).id.to_s
  end

  test "filters narrow the entries and statuses default to the non cancelled kinds" do
    login_admin

    get "/appointments", params: { date: "2026-07-20", statuses: [ "Confirmed" ] }
    assert_select ".day-entry-appointment", count: 0
    assert_select "#status-filter input[value=Booked]:not([checked])"

    get "/appointments", params: { date: "2026-07-20" }
    assert_select "#status-filter input[value=Booked][checked]"
    assert_select "#status-filter input[value=Cancelled]:not([checked])"
  end

  test "an unparseable date falls back to today" do
    login_admin
    get "/appointments", params: { date: "nonsense" }
    assert_response :success
    assert_select "#select-date[value=?]", Date.current.to_s
  end

  test "a stylist has no stylist dropdown and sees only their own column, whatever the URL asks for" do
    other = User.create!(name: "Other", email: "other@example.org", role: users(:zane).role)
    ServiceProviderLink.create!(provider: other, service: services(:haircut))
    post "/login/validate", params: { username: "janedoe", password: "janedoe1" }
    get "/appointments", params: { date: "2026-07-20", providers: [ "", other.id ] }
    assert_select "#provider-filter", count: 0
    assert_select "#service-filter"
    assert_select ".provider-column[data-provider-id=?]", users(:zane).id.to_s
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
    keys = %w[working_providers hidden_from_public slot_interval_hint messages_all_channels]
    I18n.available_locales.each do |locale|
      keys.each do |key|
        assert I18n.t("ea.#{key}", locale: locale, fallback: false, default: nil).present?, "missing ea.#{key} in #{locale}"
      end
    end
  end
end
