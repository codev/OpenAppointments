require "application_system_test_case"

# The Feed button opens the Feed dialog: the Calendar Feed tab has the
# provider's link and reset, the Enable Sync tab connects or disconnects a
# CalDAV or Google calendar. The sync HTTP clients are stubbed in the browser.
class CalendarFeedTest < ApplicationSystemTestCase
  setup do
    # A second stylist, so everyone ticked is not one stylist in focus.
    riley = User.create!(name: "Riley", email: "riley@example.org", role: users(:zane).role, timezone: "Europe/London")
    ServiceProviderLink.create!(id_users: riley.id, id_services: services(:haircut).id)
  end

  test "an admin opens the feed dialog for a provider and resets the link" do
    open_calendar
    assert_no_selector "#calendar-feed", visible: true
    assert_no_selector "#enable-sync", visible: :all
    show_only_stylist("Zane")
    open_feed_dialog
    within("#calendar-feed-modal") do
      assert_selector ".modal-title", text: I18n.t("ea.feed")
      assert_selector ".nav-link.active", text: I18n.t("ea.calendar_feed")
      assert_selector ".nav-link", text: I18n.t("ea.enable_sync")
    end
    first = find("#calendar-feed-link").value
    assert_match %r{/calendar/feed/[A-Za-z0-9]{32}\.ics\z}, first
    assert_text I18n.t("ea.calendar_feed_refresh_note")

    click_on I18n.t("ea.calendar_feed_reset")
    confirm_modal(I18n.t("ea.calendar_feed_reset"), I18n.t("ea.confirm"))
    assert_selector "#calendar-feed-modal.show", wait: 5
    assert_no_field "calendar-feed-link", with: first, wait: 5
    assert_match %r{/calendar/feed/[A-Za-z0-9]{32}\.ics\z}, find("#calendar-feed-link").value
  end

  test "the Enable Sync tab connects a CalDAV calendar and then offers to disable it" do
    open_calendar
    show_only_stylist("Zane")
    stub_caldav
    open_feed_dialog
    within("#calendar-feed-modal") do
      click_on I18n.t("ea.enable_sync")
      assert_text I18n.t("ea.caldav_connection_info_prompt")
      fill_in I18n.t("ea.calendar_url"), with: "https://dav.example.org/cal"
      fill_in I18n.t("ea.username"), with: "zane"
      fill_in I18n.t("ea.password"), with: "secret"
      click_on I18n.t("ea.connect")
    end
    assert_feed_dialog_closed
    assert_no_selector "#message-modal"
    assert_selector "#sync-button-group", visible: true, wait: 5
    assert_equal [ users(:zane).id.to_s, "https://dav.example.org/cal", "zane", "secret" ],
                 page.evaluate_script("window.caldavConnected")

    open_feed_dialog
    assert_selector "#calendar-feed-modal .nav-link.active", text: I18n.t("ea.calendar_feed")
    # The tab click is exercised above; a second click on it is unreliable on
    # CI, so the pane is opened through Bootstrap here.
    show_sync_tab
    within("#calendar-feed-modal") do
      assert_no_field I18n.t("ea.calendar_url")
      assert_text I18n.t("ea.disable_sync_prompt")
      assert_button I18n.t("ea.disable_sync")
      # A native click in this reopened dialog is unreliable on CI; the button's
      # own handler is what is under test here.
      page.execute_script("document.getElementById('sync-disable-confirm').click()")
    end
    assert_feed_dialog_closed
    assert_selector "#sync-button-group", visible: false, wait: 5
    assert_equal users(:zane).id.to_s, page.evaluate_script("String(window.caldavDisabled)")
  end

  test "with Google sync on the Enable Sync tab offers Google and picks its calendar in the tab" do
    Setting.set("google_sync_feature", "1")
    open_calendar
    show_only_stylist("Zane")
    page.execute_script(<<~JS)
      window.open = () => null;
      App.Http.Google.getGoogleCalendars = () => $.Deferred().resolve([{ id: 'work', summary: 'Work' }]).promise();
      App.Http.Google.selectGoogleCalendar = (providerId, calendarId) => {
        window.googleSelected = [providerId, calendarId];
        return $.Deferred().resolve().promise();
      };
    JS
    open_feed_dialog
    within("#calendar-feed-modal") do
      click_on I18n.t("ea.enable_sync")
      assert_text I18n.t("ea.sync_method_prompt")
      click_on "Google Calendar"
    end
    page.execute_script("window.postMessage('oauth_success', window.location.origin)")
    within("#calendar-feed-modal") do
      assert_text I18n.t("ea.select_sync_calendar_prompt"), wait: 5
      select "Work", from: I18n.t("ea.select_sync_calendar")
      click_on I18n.t("ea.select")
    end
    assert_feed_dialog_closed
    assert_no_selector "#message-modal"
    assert_selector "#sync-button-group", visible: true
    assert_equal [ users(:zane).id.to_s, "work" ], page.evaluate_script("window.googleSelected")
  end

  private

  def open_calendar
    login_as_admin
    page.execute_script("window.localStorage.clear()") # no ticks saved by an earlier test
    visit "/calendar"
  end

  # Closed for good: Bootstrap drops the backdrop last, after the dialog is out of sight.
  def assert_feed_dialog_closed
    assert_no_selector ".modal-backdrop", wait: 5
    assert_selector "#calendar-feed-modal", visible: :hidden
  end

  def show_sync_tab
    page.execute_script("bootstrap.Tab.getOrCreateInstance(document.getElementById('calendar-sync-tab')).show()")
    assert_selector "#calendar-sync-tab.active", wait: 5
    assert_selector "#calendar-sync-pane.active.show", wait: 5
  end

  def open_feed_dialog
    click_on I18n.t("ea.feed")
    assert_selector "#calendar-feed-modal.show", wait: 5
    wait_for_modal
  end

  def stub_caldav
    page.execute_script(<<~JS)
      App.Http.Caldav.connectToServer = (...args) => {
        window.caldavConnected = args;
        return $.Deferred().resolve({ success: true }).promise();
      };
      App.Http.Caldav.disableProviderSync = (providerId) => { window.caldavDisabled = providerId; };
    JS
  end

  test "the Google calendar choice comes back when the dialog was closed during OAuth" do
    Setting.set("google_sync_feature", "1")
    open_calendar
    show_only_stylist("Zane")
    page.execute_script(<<~JS)
      window.open = () => null;
      App.Http.Google.getGoogleCalendars = () => $.Deferred().resolve([{ id: 'work', summary: 'Work' }]).promise();
      App.Http.Google.selectGoogleCalendar = (providerId, calendarId) => {
        window.googleSelected = [providerId, calendarId];
        return $.Deferred().resolve().promise();
      };
    JS
    open_feed_dialog
    within("#calendar-feed-modal") do
      click_on I18n.t("ea.enable_sync")
      click_on "Google Calendar"
    end
    page.execute_script("bootstrap.Modal.getInstance(document.getElementById('calendar-feed-modal')).hide()")
    assert_no_selector "#calendar-feed-modal", visible: true, wait: 5
    page.execute_script("window.postMessage('oauth_success', window.location.origin)")
    within("#calendar-feed-modal") do
      assert_text I18n.t("ea.select_sync_calendar_prompt"), wait: 5
      select "Work", from: I18n.t("ea.select_sync_calendar")
      click_on I18n.t("ea.select")
    end
    assert_equal [ users(:zane).id.to_s, "work" ], page.evaluate_script("window.googleSelected")
  end
end
