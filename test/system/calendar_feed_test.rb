require "application_system_test_case"

# The Calendar Feed button opens the dialog with the provider's link, and
# reset replaces it.
class CalendarFeedTest < ApplicationSystemTestCase
  test "an admin opens the feed dialog for a provider and resets the link" do
    login_as_admin
    visit "/calendar"
    assert_no_selector "#calendar-feed", visible: true
    select "Zane", from: "select-filter-item"
    click_on I18n.t("ea.calendar_feed")
    assert_selector "#calendar-feed-modal[open]", wait: 5
    first = find("#calendar-feed-link").value
    assert_match %r{/calendar/feed/[A-Za-z0-9]{32}\.ics\z}, first
    assert_text I18n.t("ea.calendar_feed_refresh_note")

    click_on I18n.t("ea.calendar_feed_reset")
    confirm_modal(I18n.t("ea.calendar_feed_reset"), I18n.t("ea.confirm"))
    assert_selector "#calendar-feed-modal[open]", wait: 5
    assert_no_field "calendar-feed-link", with: first, wait: 5
    assert_match %r{/calendar/feed/[A-Za-z0-9]{32}\.ics\z}, find("#calendar-feed-link").value
  end
end
