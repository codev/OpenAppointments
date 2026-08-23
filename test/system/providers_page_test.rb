require "application_system_test_case"

# Written against the jQuery page before the Rails views conversion: labels,
# visible text and row selectors only, so it must pass on both.
class ProvidersPageTest < ApplicationSystemTestCase
  setup do
    login_as_admin
    visit providers_url
    assert_selector ".provider-row", text: "Zane", wait: 5
  end

  test "add with services and a working plan, edit the plan, links, filter and delete" do
    click_on "Add"
    assert_selector "#providers-page.editing", wait: 5
    fill_in "Name", with: "Pat Stylist"
    fill_in "Email", with: "pat@example.org"
    fill_in "Mobile Number", with: "07700 900111"
    fill_in "Username", with: "patstylist"
    fill_in "Password", with: "password1", match: :prefer_exact
    fill_in "Retype Password", with: "password1"
    select "English", from: "Language"
    select "London (+0:00)", from: "Timezone"
    check "Hide From Public"
    fill_in "About", with: "Senior stylist"
    click_on "Select None"
    check "Trim Cut"

    click_on "Working Plan"
    assert_selector "#working-plan.active", wait: 5
    assert_selector "#working-plan table.working-plan tbody tr", count: 7
    # Saturday off, Monday 10:00 to 16:00
    uncheck "Saturday" if has_checked_field?("Saturday")
    check "Monday" unless has_checked_field?("Monday")
    find("#monday-start").set("10:00 am")
    find("#monday-end").set("4:00 pm")
    click_on "Save"

    assert_text "Provider saved", wait: 5
    assert_no_selector "#providers-page.editing"
    assert_selector ".provider-row.selected", text: "Pat Stylist"
    pat = User.providers.find_by!(email: "pat@example.org")
    assert_equal "patstylist", pat.settings.username
    assert Passwords.verify(nil, "password1", pat.settings.password)
    assert pat.is_private
    assert_equal "Senior stylist", pat.about
    assert_equal [ services(:haircut).id ], pat.services.map(&:id)
    plan = JSON.parse(pat.settings.working_plan)
    assert_nil plan["saturday"]
    assert_equal({ "start" => "10:00", "end" => "16:00" }, plan["monday"].except("breaks"))
    assert_equal [ { "start" => "14:30", "end" => "15:00" } ], plan["monday"]["breaks"], "company break kept"
    assert pat.booking_slug.present?

    find(".provider-row", text: "Pat Stylist").click
    assert_selector "#providers-page.editing", wait: 5
    click_on "Details"
    assert_checked_field "Trim Cut"
    assert_selector "a[href*='?provider=#{pat.booking_slug}']"
    old_slug = pat.booking_slug
    click_on "Regenerate Link"
    confirm_modal "Regenerate Link", "Change"
    assert_selector "a[href*='?provider=#{pat.reload.booking_slug}']", wait: 5
    assert_not_equal old_slug, pat.booking_slug

    click_on "Working Plan"
    assert_selector "#working-plan.active", wait: 5
    assert_checked_field "Monday"
    assert_equal "10:00 am", find("#monday-start").value
    uncheck "Monday"
    click_on "Add Break"
    within("table.breaks tbody tr:last-child") { click_on "Save" }
    click_on "Save"
    assert_text "Provider saved", wait: 5
    plan = JSON.parse(pat.settings.reload.working_plan)
    assert_nil plan["monday"]

    find(".provider-row", text: "Zane").click
    assert_selector "#providers-page.editing", wait: 5
    click_on "Cancel"
    assert_no_selector "#providers-page.editing", wait: 5

    find("#filter-providers .key").set("stylist")
    find("#filter-providers button.filter").click
    assert_selector ".provider-row", count: 1, wait: 5
    find("#filter-providers .key").set("")
    find("#filter-providers button.filter").click
    assert_selector ".provider-row", count: 2, wait: 5

    find(".provider-row", text: "Pat Stylist").click
    assert_selector "#providers-page.editing", wait: 5
    click_on "Delete"
    confirm_modal "Delete Provider", "Delete"
    assert_text "Provider deleted", wait: 5
    assert_no_selector ".provider-row", text: "Pat Stylist"
    assert_not User.exists?(pat.id)
  end

  test "reset plan restores the company working plan" do
    find(".provider-row", text: "Zane").click
    assert_selector "#providers-page.editing", wait: 5
    click_on "Working Plan"
    assert_selector "#working-plan.active", wait: 5
    assert_unchecked_field "Wednesday"
    click_on "Reset Plan"
    assert_checked_field "Wednesday", wait: 5
    click_on "Save"
    assert_text "Provider saved", wait: 5
    plan = JSON.parse(users(:zane).settings.reload.working_plan)
    assert plan["wednesday"].present?
  end

  test "sort alphabetically clears the manual order" do
    User.create!(name: "Aaron", email: "aaron@example.org", role: Role.find_by!(slug: "provider"))
    users(:zane).update!(sort_order: 1)
    visit providers_url
    assert_selector ".provider-row:first-child", text: "Zane", wait: 5
    click_on "Sort Alphabetically"
    confirm_modal "Sort Alphabetically", "Sort Alphabetically"
    assert_selector ".provider-row:first-child", text: "Aaron", wait: 5
    assert_nil users(:zane).reload.sort_order
  end
end

# Rails views only: the editor round-trips through hidden fields, and an invalid
# plan blocks the submit client side.
class ProvidersFormTest < ApplicationSystemTestCase
  test "a start after the end keeps the form open with the message; a break and an exception save" do
    login_as_admin
    visit providers_url
    find(".provider-row", text: "Zane").click
    assert_selector "#providers-page.editing", wait: 5
    click_on "Working Plan"
    assert_selector "#working-plan.active", wait: 5
    find("#monday-start").set("5:00 pm")
    find("#monday-end").set("9:00 am")
    click_on "Save"
    assert_selector ".backend-notification", wait: 5
    assert_selector "#providers-page.editing"
    assert_equal "09:00", JSON.parse(users(:zane).settings.reload.working_plan)["monday"]["start"]

    find("#monday-start").set("9:00 am")
    find("#monday-end").set("5:00 pm")
    click_on "Add Unavailable/Holiday Days"
    assert_selector "#working-plan-exceptions-modal", visible: true, wait: 5
    within("#working-plan-exceptions-modal") do
      # flatpickr inputs (DMY in the fixtures), typed then blurred
      find("#working-plan-exceptions-start-date").set("01/09/2026\t")
      find("#working-plan-exceptions-end-date").set("01/09/2026\t")
      find("#working-plan-exceptions-save").click
    end
    assert_selector "table.working-plan-exceptions tbody tr", count: 1, wait: 5
    click_on "Save"
    assert_text "Provider saved", wait: 5
    assert_equal 1, WorkingPlanException.where(id_users_provider: users(:zane).id).count
  end
end
