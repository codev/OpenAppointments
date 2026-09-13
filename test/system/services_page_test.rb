require "application_system_test_case"

# Written against the jQuery page before the Rails views conversion: labels,
# visible text and row selectors only, so it must pass on both.
class ServicesPageTest < ApplicationSystemTestCase
  setup do
    login_as_admin
    visit services_url
    assert_selector ".service-row", text: "Trim Cut", wait: 5
  end

  test "add with defaults, category, colour and providers, then edit, links, filter and delete" do
    assert_selector ".service-row", text: "30 min"
    click_on "Add"
    assert_selector "#services-page.editing", wait: 5
    assert_field "Name", with: "Service"
    assert_field "Duration (Minutes)", with: "30"
    assert_field "Slot Interval (Minutes)", with: "15"
    assert_field "Attendants Number (Concurrent Bookings)", with: "1"
    fill_in "Name", with: "Colour"
    fill_in "Duration (Minutes)", with: "45"
    fill_in "Price", with: "40"
    fill_in "Currency", with: "GBP"
    select "Hair", from: "Category"
    fill_in "Location", with: "Back room"
    find(".color-selection-option[data-value='#eb8687']").click
    check "Hide From Public"
    fill_in "Description", with: "Full head"
    check "Zane"
    click_on "Save"

    assert_text "Service saved", wait: 5
    assert_no_selector "#services-page.editing"
    assert_selector ".service-row.selected", text: "Colour"
    assert_selector ".service-row", text: "45 min"
    colour = Service.find_by!(name: "Colour")
    assert_equal 45, colour.duration
    assert_equal 40, colour.price
    assert_equal service_categories(:hair), colour.category
    assert_equal "#eb8687", colour.color
    assert colour.is_private
    assert_equal "Back room", colour.location
    assert_equal [ users(:zane).id ], colour.providers.map(&:id)
    assert colour.booking_slug.present?

    find(".service-row", text: "Colour").click
    assert_selector "#services-page.editing", wait: 5
    assert_field "Description", with: "Full head"
    assert_checked_field "Zane"
    assert_checked_field "Hide From Public"
    assert_selector ".color-selection-option.selected[data-value='#eb8687']"
    assert_selector "a[href*='?service=#{colour.booking_slug}']"
    assert_selector "a[href*='provider=#{users(:zane).booking_slug}']"
    click_on "Select None"
    assert_unchecked_field "Zane"
    click_on "Select All"
    assert_checked_field "Zane"

    old_slug = colour.booking_slug
    click_on "Regenerate Link"
    confirm_modal "Regenerate Link", "Cancel"
    assert_equal old_slug, colour.reload.booking_slug
    click_on "Regenerate Link"
    confirm_modal "Regenerate Link", "Change"
    assert_selector "a[href*='?service=#{colour.reload.booking_slug}']", wait: 5
    assert_not_equal old_slug, colour.booking_slug

    fill_in "Price", with: "45"
    click_on "Save"
    assert_text "Service saved", wait: 5
    assert_equal 45, colour.reload.price

    find(".service-row", text: "Trim Cut").click
    assert_selector "#services-page.editing", wait: 5
    click_on "Cancel"
    assert_no_selector "#services-page.editing", wait: 5

    find("#filter-services .key").set("colo")
    find("#filter-services button.filter").click
    assert_selector ".service-row", count: 1, wait: 5
    find("#filter-services .key").set("")
    find("#filter-services button.filter").click
    assert_selector ".service-row", count: 3, wait: 5

    find(".service-row", text: "Colour").click
    assert_selector "#services-page.editing", wait: 5
    click_on "Delete"
    confirm_modal "Delete Service", "Delete"
    assert_text "Service deleted", wait: 5
    assert_no_selector ".service-row", text: "Colour"
    assert_not Service.exists?(colour.id)
  end

  test "sort alphabetically clears the manual order" do
    Service.find_by!(name: "Trim Cut").update!(sort_order: 1)
    visit services_url
    assert_selector ".service-row:first-child", text: "Trim Cut", wait: 5
    click_on "Sort Alphabetically"
    confirm_modal "Sort Alphabetically", "Sort Alphabetically"
    assert_selector ".service-row:first-child", text: "Group Session", wait: 5
    assert_nil Service.find_by!(name: "Trim Cut").sort_order
  end

  test "a missing name is rejected" do
    click_on "Add"
    assert_selector "#services-page.editing", wait: 5
    fill_in "Name", with: ""
    click_on "Save"
    assert_selector "#services-page.editing"
    assert_equal 2, Service.count
  end
end

# Rails views only: the picture is part of the form.
class ServicesFormTest < ApplicationSystemTestCase
  test "a picture chosen while adding previews and saves with the record, then can be removed" do
    login_as_admin
    visit services_url
    click_on "Add"
    assert_selector "#services-page.editing", wait: 5
    fill_in "Name", with: "Pictured"
    attach_file "Picture", file_fixture("picture.png")
    assert_selector ".picture-preview[src^='blob:']", visible: true
    click_on "Save"
    assert_text "Service saved", wait: 5
    service = Service.find_by!(name: "Pictured")
    assert service.picture.attached?

    find(".service-row", text: "Pictured").click
    assert_selector ".picture-preview[src*='/rails/']", visible: true, wait: 5
    check "Remove picture"
    click_on "Save"
    assert_text "Service saved", wait: 5
    assert_not service.reload.picture.attached?
  end
end
