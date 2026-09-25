require "application_system_test_case"

# Written against the jQuery page before the Rails views conversion: labels,
# visible text and row selectors only, so it must pass on both.
class CustomersPageTest < ApplicationSystemTestCase
  setup do
    %w[email phone_number].each { |field| Setting.set("display_#{field}", "1") }
    login_as_admin
  end

  test "clicking a customer with appointment history enters edit mode and lists the appointments" do
    visit customers_url
    assert_selector ".customer-row", wait: 5
    find(".customer-row[data-id='#{users(:jx).id}']").click
    assert_selector "#customers-page.editing", wait: 5
    assert_selector "#customer-appointments .appointment-row", text: "Trim Cut - Zane", wait: 5
    assert_selector "#customer-appointments a[href*='/calendar/reschedule/abc123def456']"
  end

  test "add, edit, filter, cancel and delete" do
    visit customers_url
    assert_selector ".customer-row", wait: 5
    click_on "Add"
    assert_selector "#customers-page.editing", wait: 5
    fill_in "Name", with: "Pat Customer"
    fill_in "Email", with: "patc@example.org"
    fill_in "Phone Number", with: "07700 900333"
    fill_in "Notes", with: "Prefers mornings"
    select "English", from: "Language"
    select "London (+0:00)", from: "Timezone"
    click_on "Save"

    assert_text "Customer saved", wait: 5
    assert_no_selector "#customers-page.editing"
    assert_selector ".customer-row.selected", text: "Pat Customer"
    assert_selector ".customer-row.selected", text: "patc@example.org, 07700 900333"
    pat = User.customers.find_by!(email: "patc@example.org")
    assert_equal "Prefers mornings", pat.notes
    assert_equal "Europe/London", pat.timezone

    find(".customer-row", text: "Pat Customer").click
    assert_selector "#customers-page.editing", wait: 5
    assert_field "Notes", with: "Prefers mornings"
    assert_text "No records found"
    fill_in "Name", with: "Pat Client"
    click_on "Save"
    assert_text "Customer saved", wait: 5
    assert_equal "Pat Client", pat.reload.name

    find(".customer-row", text: "JX").click
    assert_selector "#customers-page.editing", wait: 5
    click_on "Cancel"
    assert_no_selector "#customers-page.editing", wait: 5

    find("#filter-customers .key").set("client")
    find("#filter-customers button.filter").click
    assert_selector ".customer-row", count: 1, wait: 5
    find("#filter-customers .key").set("")
    find("#filter-customers button.filter").click
    assert_selector ".customer-row", count: 2, wait: 5

    find(".customer-row", text: "Pat Client").click
    assert_selector "#customers-page.editing", wait: 5
    click_on "Delete"
    confirm_modal "Delete Customer", "Delete"
    assert_text "Customer deleted", wait: 5
    assert_no_selector ".customer-row", text: "Pat Client"
    assert_not User.exists?(pat.id)
  end

  test "a deep link selects the customer and the messages panel lists and marks messages" do
    message = Message.create!(direction: "incoming", channel: "email", from_address: users(:jx).email,
                              customer_id: users(:jx).id, body: "Running late", status: "received")
    visit customers_url(customer_id: users(:jx).id, section: "messages")
    assert_selector ".customer-row.selected[data-id='#{users(:jx).id}']", wait: 5, visible: :all
    assert_selector ".customer-row .unread-badge", text: "1", visible: :all

    visit customers_url
    find(".customer-row[data-id='#{users(:jx).id}']").click
    assert_selector "#customers-page.editing", wait: 5
    assert_field "Name", with: "JX"
    assert_selector "#customer-messages .message-row", text: "Running late", wait: 5
    click_on "Mark all as read"
    assert_no_selector "#customer-messages .message-unread", wait: 5
    assert message.reload.read?
    click_on "Cancel"
    assert_no_selector "#customers-page.editing", wait: 5
    assert_no_selector ".customer-row .unread-badge"
  end

  test "the conversation sits below the record buttons; Enter sends, Shift-Enter adds a line, typing there is not an unsaved change" do
    visit customers_url
    find(".customer-row[data-id='#{users(:jx).id}']").click
    assert_selector "#customers-page.editing", wait: 5
    assert_selector "form.crud-form ~ #customer-conversation textarea#message-body[rows='3']", wait: 5
    assert_selector "#customer-conversation .btn-toolbar", count: 0

    box = find("#message-body")
    before = box.evaluate_script("this.offsetHeight")
    box.send_keys("Running late", [ :shift, :enter ], "back at three", [ :shift, :enter ], "sorry", [ :shift, :enter ], "again")
    assert_equal "Running late\nback at three\nsorry\nagain", box.value
    assert_operator box.evaluate_script("this.offsetHeight"), :>, before

    select "Email", from: "message-channel"
    box.send_keys(:enter)
    assert_selector "#customer-messages .message-row", text: "Running late", wait: 5
    assert Message.outgoing.last.body.start_with?("Running late\nback at three\nsorry\nagain\n"), "the line breaks should be kept"
    assert_equal "", box.value
    assert_equal before, box.evaluate_script("this.offsetHeight")

    box.send_keys("draft never sent")
    click_on "Calendar"
    assert_no_selector "#message-modal", wait: 2
    assert_selector "#calendar-page", wait: 5
  end
end

# Admins delete a single message from the conversation after a confirm.
class CustomerMessageDeleteTest < ApplicationSystemTestCase
  test "an admin deletes one message from the conversation" do
    Message.create!(direction: "incoming", channel: "email", from_address: users(:jx).email,
                    customer_id: users(:jx).id, body: "Keep me", status: "received")
    gone = Message.create!(direction: "incoming", channel: "email", from_address: users(:jx).email,
                           customer_id: users(:jx).id, body: "Delete me", status: "received")
    login_as_admin
    visit customers_url(customer_id: users(:jx).id, section: "messages")
    assert_selector "#customer-messages .message-row", text: "Delete me", wait: 5

    find("#customer-messages .message-row", text: "Delete me").find(".delete-message").click
    confirm_modal "Delete", "Delete"
    assert_no_selector "#customer-messages .message-row", text: "Delete me", wait: 5
    assert_selector "#customer-messages .message-row", text: "Keep me"
    assert_text "Message deleted"
    assert_not Message.exists?(gone.id)
  end
end

# Rails views only: the deep link opens the record on the conversation panel.
class CustomersDeepLinkTest < ApplicationSystemTestCase
  test "the messages deep link opens the customer with the conversation loaded" do
    Message.create!(direction: "incoming", channel: "email", from_address: users(:jx).email,
                    customer_id: users(:jx).id, body: "Running late", status: "received")
    login_as_admin
    visit customers_url(customer_id: users(:jx).id, section: "messages")
    assert_selector "#customers-page.editing", wait: 5
    assert_field "Name", with: "JX"
    assert_selector "#customer-messages .message-row.message-unread", text: "Running late", wait: 5
    assert_selector "#mark-all-read", visible: true
  end
end
