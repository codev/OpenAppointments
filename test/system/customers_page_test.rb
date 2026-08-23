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
end
