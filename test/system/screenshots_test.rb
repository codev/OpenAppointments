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
  end
end
