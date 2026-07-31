require "application_system_test_case"

class CustomersPageTest < ApplicationSystemTestCase
  test "clicking a customer with appointment history enters edit mode" do
    visit login_url
    fill_in "username", with: "administrator"
    fill_in "password", with: "administrator1"
    find("#login").click
    assert_current_path %r{/calendar}, wait: 5

    visit customers_url
    assert_selector ".customer-row", wait: 5
    find(".customer-row[data-id='#{users(:jx).id}']").click
    assert_selector "#customers-page.editing", wait: 5
    assert_selector "#customer-appointments .appointment-row, #customer-appointments div", wait: 5
  end
end
