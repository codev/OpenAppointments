require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  # Plain Chrome (CI) works as-is. A snap-packaged Chromium (local dev) can only
  # write inside the snap area, so give it a profile dir there and skip the sandbox.
  SNAP_CHROMIUM = "/snap/bin/chromium".freeze

  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ] do |options|
    if File.exist?(SNAP_CHROMIUM) && !system("which google-chrome > /dev/null 2>&1")
      profile_dir = File.expand_path("~/snap/chromium/common/selenium-profile")
      FileUtils.mkdir_p(profile_dir)
      options.binary = SNAP_CHROMIUM
      options.add_argument("--no-sandbox")
      options.add_argument("--disable-dev-shm-usage")
      options.add_argument("--user-data-dir=#{profile_dir}")
    end
  end
end
