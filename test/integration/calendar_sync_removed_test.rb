require "test_helper"

# The Google Calendar and CalDAV sync integrations are gone: no OAuth or
# settings routes, no Sync button on the calendar, and the Feed dialog only
# carries the subscription link. The "Add to Google Calendar" link on the
# booking confirmed page stays, switched from Booking settings.
class CalendarSyncRemovedTest < ActionDispatch::IntegrationTest
  def login_admin
    post "/login/validate", params: { username: "administrator", password: "administrator1" }
  end

  test "the sync routes no longer exist" do
    login_admin
    %w[/google/oauth/1 /google_calendar_settings /google/oauth_callback].each do |path|
      get path
      assert_response :not_found, path
    end
    post "/google_calendar_settings/save"
    assert_response :not_found
    post "/google/disable_provider_sync"
    assert_response :not_found
  end

  test "the calendar page has no Sync button, sync attributes or sync scripts" do
    login_admin
    get "/calendar"
    assert_response :success
    assert_select "#sync-button-group", 0
    assert_select "#select-filter-item option[google-sync]", 0
    assert_select "#select-filter-item option[caldav-sync]", 0
    assert_select "#calendar-feed-modal #calendar-sync-pane", 0
    assert_select "#calendar-feed-modal .nav-tabs", 0
    assert_select "#calendar-feed-modal input#calendar-feed-link[readonly]"
    assert_no_match "calendar_sync", response.body
    assert_no_match "google_http_client", response.body
    assert_no_match "caldav_http_client", response.body
    assert_no_match "google_sync_feature", response.body
  end

  test "the Integrations page has no Google Calendar card" do
    login_admin
    get "/integrations"
    assert_select "a[href='/google_calendar_settings']", 0
    assert_select "a[href='/google_analytics_settings']"
  end

  test "the Add to Google Calendar switch lives on Booking settings and drives the confirmed page" do
    login_admin
    get "/booking_settings"
    assert_select "input#display-add-to-google-calendar[name='settings[display_add_to_google_calendar]']"
    assert_select "label[for='display-add-to-google-calendar']", text: I18n.t("ea.display_add_to_google_calendar")

    Setting.set("display_add_to_google_calendar", "0")
    get "/booking_confirmation/of/#{appointments(:upcoming).booking_hash}"
    assert_select "#add-to-google-calendar", 0
    Setting.set("display_add_to_google_calendar", "1")
    get "/booking_confirmation/of/#{appointments(:upcoming).booking_hash}"
    assert_select "#add-to-google-calendar"
  end

  test "no sync code, gems or scheduler entry remain" do
    %w[app/controllers/google_controller.rb app/controllers/google_calendar_settings_controller.rb
       app/services/google_calendar_gateway.rb app/services/caldav_gateway.rb app/services/synchronization.rb
       app/services/calendar_pull.rb app/lib/sync_urls.rb app/jobs/google_sync_appointment_job.rb
       app/jobs/caldav_sync_appointment_job.rb app/javascript/utils/calendar_sync.js
       app/javascript/http/google_http_client.js app/javascript/http/caldav_http_client.js].each do |path|
      assert_not Rails.root.join(path).exist?, "#{path} still exists"
    end
    gemfile = Rails.root.join("Gemfile").read
    assert_no_match(/google-apis-calendar_v3|googleauth/, gemfile)
    manifest = JSON.parse(Rails.root.join("CloudronManifest.json").read)
    assert_nil manifest.dig("addons", "scheduler", "sync")
    assert manifest.dig("addons", "scheduler", "cleanup")
    assert_no_match(/openappointments:sync\b/, Rails.root.join("README.md").read)
  end
end
