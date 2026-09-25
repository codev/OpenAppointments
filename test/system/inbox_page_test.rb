require "application_system_test_case"

# Done and Undo work in place: the row leaves the list and the header badge
# follows, without reloading the page.
class InboxPageTest < ApplicationSystemTestCase
  test "done removes the row and lowers the badge; undo from show done brings it back" do
    message = Message.create!(direction: "incoming", channel: "email", from_address: users(:jx).email,
                              customer_id: users(:jx).id, body: "Running late", status: "received")
    login_as_admin
    visit "/inbox"
    assert_selector "#inbox-unread", text: "1"
    page.execute_script("window.__inboxMarker = 1")

    within("#inbox-message-#{message.id}") { click_on "Done" }
    assert_no_selector "#inbox-message-#{message.id}", wait: 5
    assert_selector "#inbox-unread", visible: false
    assert_equal 1, page.evaluate_script("window.__inboxMarker")
    assert message.reload.done?

    click_on "Show done"
    within("#inbox-message-#{message.id}") do
      assert_text "Done by Edson Mori"
      click_on "Undo"
    end
    assert_no_selector "#inbox-message-#{message.id}", wait: 5
    assert_not message.reload.done?
  end
end
