require "application_system_test_case"

# Turbo Drive is on: moving between backend pages through the header and side
# menus must keep the window (a marker survives) and every page must initialise
# from turbo:load.
class TurboDriveTest < ApplicationSystemTestCase
  def drive_to(link_text, within_selector = "#header")
    within(within_selector) { click_on link_text, match: :first }
  end

  def assert_driven
    assert_equal 1, page.evaluate_script("window.__driveMarker"), "the page was reloaded in full"
  end

  test "the header, settings and messages menus drive between pages and each page initialises" do
    login_as_admin
    page.execute_script("window.__driveMarker = 1")

    drive_to "Appointments"
    assert_selector "#day-filter", wait: 5
    assert_driven

    drive_to "Customers"
    assert_selector "#customers-page", wait: 5
    assert_driven
    click_on "Add"
    assert_selector "#customers-page.editing .crud-form", wait: 5
    assert_driven

    find("#header .dropdown-toggle", text: "Services").click
    find("#header a.dropdown-item[href='/services']").click
    assert_selector "#services-page", wait: 5
    assert_driven
    find(".service-row", text: "Trim Cut").click
    assert_selector "#services-page.editing", wait: 5
    assert_selector ".color-selection-option.selected"
    assert_driven

    find("#header .dropdown-toggle", text: "Users").click
    click_on "Providers"
    assert_selector "#providers-page", wait: 5
    find(".provider-row", text: "Zane").click
    assert_selector "#providers-page.editing", wait: 5
    click_on "Working Plan"
    assert_selector "#working-plan table.working-plan tbody tr", count: 7, wait: 5
    assert_driven

    drive_to "Calendar"
    assert_selector "#calendar .fc-view-harness", wait: 10
    assert_driven

    find("#header a[aria-label='Settings']").click
    find("#header a.dropdown-item[href='/general_settings']").click
    assert_selector "#company-name", wait: 5
    assert_driven
    within("#settings-nav") { click_on "Business Logic" }
    assert_selector "table.working-plan tbody tr", count: 7, wait: 5
    assert_driven
    within("#settings-nav") { click_on "Booking Settings" }
    assert_selector "#display-email", wait: 5
    assert_driven
    within("#settings-nav") { click_on "Legal Contents" }
    assert_selector ".trumbowyg-editor", wait: 5
    assert_driven
    within("#settings-nav") { click_on "Integrations" }
    assert_selector "a[href='/ldap_settings']", wait: 5
    find("a[href='/ldap_settings']").click
    assert_selector "#ldap-host", wait: 5
    assert_driven

    find("#header a[aria-label='Settings']").click
    find("#header a.dropdown-item[href='/messages_settings']").click
    assert_selector "#messages-nav", wait: 5
    within("#messages-nav") { click_on "Notifications" }
    assert_selector "#add-notification", wait: 5
    assert_driven

    # An edited settings page asks before a Drive visit leaves it.
    within("#messages-nav") { click_on "Settings" }
    assert_selector "#messages-retention-days", wait: 5
    fill_in "messages-retention-days", with: "7"
    drive_to "Appointments"
    assert_selector "#message-modal .modal-title", text: "Settings", wait: 5
    within("#message-modal") { click_on "Cancel" }
    assert_no_selector "#message-modal", wait: 5
    assert_selector "#messages-retention-days"
    drive_to "Appointments"
    within("#message-modal") { click_on "Leave page" }

    assert_selector "#day-filter", wait: 5
    find("#calendar-actions [data-bs-toggle=dropdown]").click
    find("#insert-appointment").click
    assert_selector "#save-appointment", visible: true, wait: 5
    assert_driven
    errors = page.driver.browser.logs.get(:browser).select { |log| log.level == "SEVERE" }.map(&:message)
                 .reject { |m| m.include?("404") }
    assert_empty errors
  end
end
