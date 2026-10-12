require "application_system_test_case"

# Save stays disabled until something on the form changes: typing, a widget's
# own buttons (add a break, insert a token), and again after a save.
class FormActionsTest < ApplicationSystemTestCase
  setup { login_as_admin }

  test "a settings page enables Save on a change and disables it again after saving" do
    visit "/general_settings"
    assert_selector "#save-settings[disabled]", wait: 5
    find("#company-name").set("Open Out Test")
    assert_selector "#save-settings:not([disabled])", wait: 5
    click_on "Save"
    assert_text "Settings saved", wait: 5
    assert_selector "#save-settings[disabled]", wait: 5
  end

  test "a record form enables Save when a field changes" do
    visit "/customers/#{users(:jx).id}/edit"
    assert_selector "form.crud-form button[data-save][disabled]", wait: 5
    fill_in "Notes", with: "Prefers mornings"
    assert_selector "form.crud-form button[data-save]:not([disabled])", wait: 5
  end

  test "a record opened from the list starts with Save disabled" do
    visit customers_url
    find(".customer-row[data-id='#{users(:jx).id}']").click
    assert_selector "form.crud-form button[data-save][disabled]", wait: 5
  end

  test "widget buttons inside the form count as a change" do
    visit "/business_settings"
    assert_selector "#save-settings[disabled]", wait: 5
    first(".add-break").click
    assert_selector "#save-settings:not([disabled])", wait: 5
  end

  test "buttons that act elsewhere leave Save disabled" do
    visit "/business_settings"
    assert_selector "#save-settings[disabled]", wait: 5
    find("#apply-global-working-plan").click
    assert_selector "#message-modal", wait: 5
    assert_selector "#save-settings[disabled]", visible: :all
  end

  test "the account page enables Save on a change" do
    visit "/account"
    assert_selector "#save-settings[disabled]", wait: 5
    find("#account-form input[type=email]").set("edson.new@example.org")
    assert_selector "#save-settings:not([disabled])", wait: 5
  end
end
