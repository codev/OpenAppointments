require "application_system_test_case"

# Not a test of behaviour: with SCREENSHOTS=1 it saves pictures of the pages
# named in SCREENSHOT_PATHS (comma separated, default the style guide) to
# tmp/screenshots for a look during stylesheet work.
class ScreenshotsTest < ApplicationSystemTestCase
  test "pages are pictured" do
    skip "set SCREENSHOTS=1" unless ENV["SCREENSHOTS"]
    login_as_admin
    resize_window(1280, 900)
    ENV.fetch("SCREENSHOT_PATHS", "/styleguide").split(",").each do |path|
      visit path
      sleep 0.5
      name = path.gsub(/[^a-z0-9]+/i, "-").delete_prefix("-").presence || "root"
      page.save_screenshot(Rails.root.join("tmp", "screenshots", "#{name}.png").to_s)
    end
    return unless ENV["SCREENSHOT_WIZARD"]

    visit "/booking"
    select services(:haircut).name, from: "select-service"
    page.save_screenshot(Rails.root.join("tmp", "screenshots", "wizard-1.png").to_s)
    find("#button-next-1").click
    assert_selector "#wizard-frame-2", wait: 5
    select "Zane", from: "select-provider"
    find("#button-next-2").click
    assert_selector "#available-hours .available-hour", minimum: 1, wait: 10
    page.save_screenshot(Rails.root.join("tmp", "screenshots", "wizard-3.png").to_s)
    first("#available-hours .available-hour").click
    find("#button-next-3").click
    assert_selector "#wizard-frame-4", wait: 5
    page.save_screenshot(Rails.root.join("tmp", "screenshots", "wizard-4.png").to_s)
  end
end
