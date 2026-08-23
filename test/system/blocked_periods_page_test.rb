require "application_system_test_case"

# Written against the jQuery page before the Rails views conversion: labels,
# visible text and row selectors only, so it must pass on both.
class BlockedPeriodsPageTest < ApplicationSystemTestCase
  setup do
    BlockedPeriod.create!(name: "Easter", start_datetime: "2026-04-03 00:00", end_datetime: "2026-04-07 00:00")
    login_as_admin
    visit blocked_periods_url
    assert_selector ".blocked-period-row", text: "Easter", wait: 5
  end

  test "add, edit, cancel, filter and delete" do
    assert_selector "a", text: "Back"
    click_on "Add"
    assert_selector "#blocked-periods-page.editing", wait: 5
    fill_in "Name", with: "Xmas"
    fill_in "Notes", with: "Closed"
    click_on "Save"

    assert_text "Blocked period saved", wait: 5
    assert_no_selector "#blocked-periods-page.editing"
    assert_selector ".blocked-period-row.selected", text: "Xmas"
    xmas = BlockedPeriod.find_by!(name: "Xmas")
    assert_equal "Closed", xmas.notes
    assert_equal "#{Date.current} 00:00", xmas.start_datetime.strftime("%F %H:%M")
    assert_equal "#{Date.tomorrow} 00:00", xmas.end_datetime.strftime("%F %H:%M")

    find(".blocked-period-row", text: "Xmas").click
    assert_selector "#blocked-periods-page.editing", wait: 5
    assert_field "Name", with: "Xmas"
    fill_in "Name", with: "Christmas"
    click_on "Save"
    assert_text "Blocked period saved", wait: 5
    assert_selector ".blocked-period-row.selected", text: "Christmas"
    assert_equal "Christmas", xmas.reload.name

    find(".blocked-period-row", text: "Easter").click
    assert_selector "#blocked-periods-page.editing", wait: 5
    click_on "Cancel"
    assert_no_selector "#blocked-periods-page.editing", wait: 5

    find("#filter-blocked-periods .key").set("east")
    find("#filter-blocked-periods button.filter").click
    assert_selector ".blocked-period-row", count: 1, wait: 5
    assert_selector ".blocked-period-row", text: "Easter"
    find("#filter-blocked-periods .key").set("")
    find("#filter-blocked-periods button.filter").click
    assert_selector ".blocked-period-row", count: 2, wait: 5

    find(".blocked-period-row", text: "Christmas").click
    assert_selector "#blocked-periods-page.editing", wait: 5
    click_on "Delete"
    confirm_modal "Delete Blocked Period", "Cancel"
    assert BlockedPeriod.exists?(xmas.id)
    click_on "Delete"
    confirm_modal "Delete Blocked Period", "Delete"
    assert_text "Blocked period deleted", wait: 5
    assert_no_selector ".blocked-period-row", text: "Christmas"
    assert_not BlockedPeriod.exists?(xmas.id)
  end

  test "a missing name is rejected" do
    click_on "Add"
    assert_selector "#blocked-periods-page.editing", wait: 5
    click_on "Save"
    assert_selector "#blocked-periods-page.editing"
    assert_equal 1, BlockedPeriod.count
  end
end
