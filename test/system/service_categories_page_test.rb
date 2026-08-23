require "application_system_test_case"

class ServiceCategoriesPageTest < ApplicationSystemTestCase
  setup do
    visit login_url
    fill_in "username", with: "administrator"
    fill_in "password", with: "administrator1"
    find("#login").click
    assert_current_path %r{/calendar}, wait: 5
    visit service_categories_url
    assert_selector ".service-category-row", wait: 5
  end

  test "the list shows full width and add, save, cancel, edit and delete work in place" do
    page_path = current_path
    list = find("#filter-service-categories")
    assert list.native.size.width > 600, "list column is narrow: #{list.native.size.width}px"
    assert_no_selector ".record-details form", visible: true

    click_on "Add"
    assert_selector "#service-categories-page.editing", wait: 5
    assert_selector "#service-category-form", visible: true
    assert_no_selector "#filter-service-categories", visible: true
    fill_in "service_category[name]", with: "Beard"
    click_on "Save"

    assert_selector ".alert-success", text: "Service category saved", wait: 5
    assert_selector ".service-category-row.selected strong", text: "Beard", visible: :all
    assert_selector "#service-category-form input[name='service_category[name]'][value='Beard']"
    assert_equal page_path, current_path, "frames must not navigate the page"

    click_on "Cancel"
    assert_no_selector "#service-categories-page.editing", wait: 5
    assert_selector "#filter-service-categories", visible: true
    assert_selector ".service-category-row strong", text: "Beard"

    find(".service-category-row[data-id='#{service_categories(:hair).id}']").click
    assert_selector "#service-categories-page.editing", wait: 5
    assert_field "service_category[name]", with: "Hair"

    accept_confirm { click_on "Delete" }
    assert_selector ".alert-success", text: "Service category deleted", wait: 5
    assert_no_selector ".service-category-row[data-id='#{service_categories(:hair).id}']", visible: :all
    assert_no_selector "#service-categories-page.editing"
  end

  test "filtering and sort alphabetically reload the list in place" do
    ServiceCategory.create!(name: "Beard", sort_order: 1)
    visit service_categories_url
    assert_equal %w[Beard Hair], all(".service-category-row strong").map(&:text)

    fill_in "keyword", with: "hai"
    find("#filter-service-categories button.filter").click
    assert_selector ".service-category-row", count: 1, wait: 5
    assert_selector ".service-category-row strong", text: "Hair"

    fill_in "keyword", with: ""
    find("#filter-service-categories button.filter").click
    assert_selector ".service-category-row", count: 2, wait: 5

    ServiceCategory.update_all(sort_order: nil)
    ServiceCategory.find_by!(name: "Hair").update!(sort_order: 1)
    accept_confirm { click_on "Sort Alphabetically" }
    assert_selector ".service-category-row:first-child strong", text: "Beard", wait: 5
    assert_nil ServiceCategory.find_by!(name: "Hair").reload.sort_order
  end
end
