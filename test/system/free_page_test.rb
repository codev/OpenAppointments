require "application_system_test_case"

# The Free page's date range: the fields reload the columns in place, Reset
# returns to the booking window.
class FreePageTest < ApplicationSystemTestCase
  test "picking dates reloads the free slots and Reset puts the window back" do
    Setting.set("future_booking_limit", "4")
    login_as_admin
    travel_to Time.new(2026, 7, 19, 12, 0, 0) do
      visit free_url
      assert_selector ".date-column h5", text: "20/07/2026", wait: 5
      assert_selector "#free-reset.disabled"

      page.execute_script("const f = document.getElementById('free-from'); f.value = '2026-07-21'; f.dispatchEvent(new Event('change'));")
      assert_no_selector ".date-column h5", text: "20/07/2026", wait: 5
      assert_selector ".date-column h5", text: "21/07/2026"
      assert_selector "#free-reset:not(.disabled)"
      assert_current_path %r{/free\?.*from=2026-07-21}

      click_on "Reset"
      assert_selector ".date-column h5", text: "20/07/2026", wait: 5
      assert_selector "#free-reset.disabled"
      assert_current_path "/free"
    end
  end
end
