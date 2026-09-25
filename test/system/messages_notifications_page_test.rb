require "application_system_test_case"

class MessagesNotificationsPageTest < ApplicationSystemTestCase
  test "add a template, see its blocks follow the event, save, fold and delete" do
    login_as_admin
    visit "/messages_notifications"
    click_on "Add"
    assert_selector ".notification-panel .notification-body", visible: true, wait: 5
    within(".notification-panel[data-id='']") do
      fill_in "Title", with: "Day before"
      assert_selector ".notification-title-display", text: "Day before"
      select "Appointment Coming Up", from: "Event"
      assert_selector ".coming-up-block", visible: true
      find("select[name='notification[lead_mode]']").select "Send a number of days before, at a set time"
      assert_selector ".lead-day-at-block", visible: true
      assert_selector ".lead-before-block", visible: false
      find("input[name='notification[audiences][]'][value=customer]").check
      find("input[name='notification[short_text]']").fill_in with: "See you tomorrow"
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

  def panel(notification) = ".notification-panel[data-id='#{notification.id}']"

  def short_text_field = find("input[name='notification[short_text]']")

  test "saving one panel keeps the edits in the others and leaving with unsaved edits asks first" do
    first = Notification.create!(title: "First", event: "created", short_text: "one", long_text: "")
    second = Notification.create!(title: "Second", event: "created", short_text: "two", long_text: "")
    login_as_admin
    visit "/messages_notifications"
    click_on "Open all notification templates"

    within(panel(first)) { short_text_field.fill_in with: "one edited" }
    click_on "Add"
    within(".notification-panel[data-id='']") do
      fill_in "Title", with: "Third"
      short_text_field.fill_in with: "three typed"
    end
    within(panel(second)) do
      short_text_field.fill_in with: "two saved"
      click_on "Save"
      assert_text "Notification saved", wait: 5
    end

    assert_equal "two saved", second.reload.short_text
    assert_equal "one", first.reload.short_text
    within(panel(first)) { assert_equal "one edited", short_text_field.value }
    within(".notification-panel[data-id='']") { assert_equal "three typed", short_text_field.value }

    within("#messages-nav") { click_on "Settings" }
    assert_selector "#message-modal .modal-title", wait: 5
    within("#message-modal") { click_on "Cancel" }
    assert_no_selector "#message-modal", wait: 5

    within(panel(first)) do
      click_on "Save"
      assert_text "Notification saved", wait: 5
    end
    within(".notification-panel[data-id='']") { click_on "Save" }
    assert_no_selector ".notification-panel[data-id='']", wait: 5
    assert_equal "three typed", Notification.find_by!(title: "Third").short_text
    assert_equal "one edited", first.reload.short_text

    within("#messages-nav") { click_on "Settings" }
    assert_selector "#messages-retention-days", wait: 5
  end

  test "a template with an unknown token saves with a warning and is marked in the list" do
    notification = Notification.create!(title: "Typo", event: "created", short_text: "Hi", long_text: "")
    login_as_admin
    visit "/messages_notifications"
    find("#{panel(notification)} .notification-header").click
    within(panel(notification)) do
      short_text_field.fill_in with: "Hi {{Custmer Name}}"
      click_on "Save"
      assert_selector ".alert-warning", text: "{{Custmer Name}}", wait: 5
      assert_selector ".notification-header .unknown-tokens-badge", text: "Unknown tokens"
    end
    assert_equal "Hi {{Custmer Name}}", notification.reload.short_text
  end
end
