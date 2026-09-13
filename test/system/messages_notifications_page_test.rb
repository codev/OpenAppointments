require "application_system_test_case"

class MessagesNotificationsPageTest < ApplicationSystemTestCase
  test "add a template, see its blocks follow the event, save, fold and delete" do
    login_as_admin
    visit "/messages_notifications"
    click_on "Add"
    assert_selector ".notification-panel .notification-body", visible: true, wait: 5
    within(".notification-panel[data-id='']") do
      fill_in "title-0", with: "Day before"
      assert_selector ".notification-title-display", text: "Day before"
      select "Appointment Coming Up", from: "event-0"
      assert_selector ".coming-up-block", visible: true
      select "Send a number of days before, at a set time", from: "lead-mode-0"
      assert_selector ".lead-day-at-block", visible: true
      assert_selector ".lead-before-block", visible: false
      check "audience-customer-0"
      fill_in "short-text-0", with: "See you tomorrow"
      click_on "Save"
    end
    assert_text "Notification saved", wait: 5
    notification = Notification.find_by!(title: "Day before")
    assert_equal "day_at", notification.lead_mode
    assert_selector ".notification-panel[data-id='#{notification.id}'] .notification-body", visible: true

    find(".notification-panel[data-id='#{notification.id}'] .notification-header").click
    assert_selector ".notification-panel[data-id='#{notification.id}'] .notification-body", visible: false
    click_on "Open all notification templates"
    assert_selector ".notification-panel[data-id='#{notification.id}'] .notification-body", visible: true

    within(".notification-panel[data-id='#{notification.id}']") { click_on "Delete" }
    confirm_modal "Delete Notification", "Delete"
    assert_no_selector ".notification-panel[data-id='#{notification.id}']", wait: 5
    assert_nil Notification.find_by(id: notification.id)
  end
end
