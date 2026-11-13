require "application_system_test_case"

# The Feed button opens the Feed dialog with the provider's subscription link
# and its reset.
class CalendarFeedTest < ApplicationSystemTestCase
  setup do
    # A second stylist, so everyone ticked is not one stylist in focus.
    riley = User.create!(name: "Riley", email: "riley@example.org", role: users(:zane).role, timezone: "Europe/London")
    ServiceProviderLink.create!(id_users: riley.id, id_services: services(:haircut).id)
  end

  test "an admin opens the feed dialog for a provider and resets the link" do
    open_calendar
    assert_no_selector "#calendar-feed", visible: true
    show_only_stylist("Zane")
    open_feed_dialog
    within("#calendar-feed-modal") do
      assert_selector ".modal-title", text: I18n.t("ea.feed")
      assert_text I18n.t("ea.calendar_feed_hint")
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

  test "the window is shown with the link and saved from the dialog" do
    users(:zane).settings.update!(sync_past_days: 10, sync_future_days: 20)
    open_calendar
    show_only_stylist("Zane")
    open_feed_dialog
    assert_field "calendar-feed-past-days", with: "10"
    assert_field "calendar-feed-future-days", with: "20"

    fill_in "calendar-feed-past-days", with: "7"
    fill_in "calendar-feed-future-days", with: "9999"
    click_on I18n.t("ea.save")
    assert_selector "#calendar-feed-window-save", text: I18n.t("ea.calendar_feed_window_saved"), wait: 5
    assert_field "calendar-feed-future-days", with: "3650"
    settings = users(:zane).settings.reload
    assert_equal [ 7, 3650 ], [ settings.sync_past_days, settings.sync_future_days ]
  end

  private

  def open_calendar
    login_as_admin
    page.execute_script("window.localStorage.clear()") # no ticks saved by an earlier test
    visit "/calendar"
  end

  def open_feed_dialog
    click_on I18n.t("ea.feed")
    assert_selector "#calendar-feed-modal.show", wait: 5
    wait_for_modal
  end
end
