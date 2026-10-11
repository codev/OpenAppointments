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

    click_on "Archive"
    within("#inbox-message-#{message.id}") do
      assert_text "Done by Edson Mori"
      click_on "Undo"
    end
    assert_no_selector "#inbox-message-#{message.id}", wait: 5
    assert_not message.reload.done?
  end

  test "the Mark as read link in the bubble marks the row read in place" do
    message = Message.create!(direction: "incoming", channel: "email", from_address: users(:jx).email,
                              customer_id: users(:jx).id, body: "Running late", status: "received")
    login_as_admin
    visit "/inbox"
    page.execute_script("window.__inboxMarker = 1")
    within("#inbox-message-#{message.id} .bubble-when") { click_on "Mark as read" }
    assert_no_selector "#inbox-message-#{message.id}.message-unread", wait: 5
    assert_selector "#inbox-unread", visible: false
    assert_equal 1, page.evaluate_script("window.__inboxMarker"), "the link must not reload the page"
    assert message.reload.read?
  end

  test "a long message fills the line up to Done; a short one stays the width of its text" do
    long = Message.create!(direction: "incoming", channel: "email", from_address: users(:jx).email,
                           customer_id: users(:jx).id, body: "Running late " * 40, status: "received")
    short = Message.create!(direction: "incoming", channel: "email", from_address: users(:jx).email,
                            customer_id: users(:jx).id, body: "Hi", status: "received")
    login_as_admin
    visit "/inbox"
    rect = "JSON.parse(JSON.stringify(this.getBoundingClientRect()))"
    bubble = find("#inbox-message-#{long.id} .bubble").evaluate_script(rect)
    done = find("#inbox-message-#{long.id} .inbox-actions .btn").evaluate_script(rect)
    assert_operator done["top"], :<, bubble["bottom"], "Done stays on the bubble's line"
    assert_operator done["left"] - bubble["right"], :<, 20, "the bubble reaches Done"

    row = find("#inbox-message-#{short.id} .inbox-row").evaluate_script(rect)
    assert_operator find("#inbox-message-#{short.id} .bubble").evaluate_script(rect)["width"], :<, row["width"] / 2
  end

  test "an unknown sender's message is deleted from the inbox after the confirm" do
    message = Message.create!(direction: "incoming", channel: "email", from_address: "who@example.org",
                              body: "Who is this?", status: "received")
    login_as_admin
    visit "/inbox"
    within("#inbox-message-#{message.id}") { find("button[title='Delete']").click }
    assert_selector "#message-modal", text: "Delete this message permanently?", wait: 5
    within("#message-modal") { click_on "Delete" }
    assert_no_selector "#inbox-message-#{message.id}", wait: 5
    assert_not Message.exists?(message.id)
  end
end
