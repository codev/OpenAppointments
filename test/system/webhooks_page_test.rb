require "application_system_test_case"

# Written against the jQuery page before the Rails views conversion: labels,
# visible text and row selectors only, so it must pass on both.
class WebhooksPageTest < ApplicationSystemTestCase
  setup do
    Webhook.create!(name: "Old hook", url: "https://hooks.example.org/old", actions: "appointment_save")
    login_as_admin
    visit webhooks_url
    assert_selector ".webhook-row", text: "Old hook", wait: 5
  end

  test "add with actions, edit, cancel, filter and delete" do
    assert_selector "a", text: "Back"
    assert_selector ".webhook-row", text: "1 Actions"
    click_on "Add"
    assert_selector "#webhooks-page.editing", wait: 5
    fill_in "Name", with: "Sheet sync"
    fill_in "URL", with: "https://hooks.example.org/sheet"
    fill_in "Secret Header", with: "X-Token"
    fill_in "Secret Token", with: "sekrit"
    check "Appointment Save"
    check "Customer Delete"
    check "Verify SSL"
    fill_in "Notes", with: "Zapier"
    click_on "Save"

    assert_text "Webhook saved", wait: 5
    assert_no_selector "#webhooks-page.editing"
    assert_selector ".webhook-row.selected", text: "Sheet sync"
    assert_selector ".webhook-row", text: "2 Actions"
    hook = Webhook.find_by!(name: "Sheet sync")
    assert_equal %w[appointment_save customer_delete], hook.action_list.sort
    assert_equal "X-Token", hook.secret_header
    assert_equal "sekrit", hook.secret_token
    assert hook.is_ssl_verified
    assert_equal "Zapier", hook.notes

    find(".webhook-row", text: "Sheet sync").click
    assert_selector "#webhooks-page.editing", wait: 5
    assert_field "URL", with: "https://hooks.example.org/sheet"
    assert_checked_field "Customer Delete"
    assert_unchecked_field "Service Save"
    uncheck "Customer Delete"
    uncheck "Verify SSL"
    click_on "Save"
    assert_text "Webhook saved", wait: 5
    assert_equal %w[appointment_save], hook.reload.action_list
    assert_not hook.is_ssl_verified

    find(".webhook-row", text: "Old hook").click
    assert_selector "#webhooks-page.editing", wait: 5
    click_on "Cancel"
    assert_no_selector "#webhooks-page.editing", wait: 5

    find("#filter-webhooks .key").set("sheet")
    find("#filter-webhooks button.filter").click
    assert_selector ".webhook-row", count: 1, wait: 5
    assert_selector ".webhook-row", text: "Sheet sync"
    find("#filter-webhooks .key").set("")
    find("#filter-webhooks button.filter").click
    assert_selector ".webhook-row", count: 2, wait: 5

    find(".webhook-row", text: "Sheet sync").click
    assert_selector "#webhooks-page.editing", wait: 5
    click_on "Delete"
    confirm_modal "Delete Webhook", "Cancel"
    assert Webhook.exists?(hook.id)
    click_on "Delete"
    confirm_modal "Delete Webhook", "Delete"
    assert_text "Webhook deleted", wait: 5
    assert_no_selector ".webhook-row", text: "Sheet sync"
    assert_not Webhook.exists?(hook.id)
  end

  test "a missing url is rejected" do
    click_on "Add"
    assert_selector "#webhooks-page.editing", wait: 5
    fill_in "Name", with: "No url"
    click_on "Save"
    assert_selector "#webhooks-page.editing"
    assert_nil Webhook.find_by(name: "No url")
  end
end
