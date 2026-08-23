# Browser tests run one at a time: a Chrome per core starves the box and flakes.
# Set before test_helper configures parallelisation.
ENV["PARALLEL_WORKERS"] ||= "1"
require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  # Plain Chrome (CI) works as-is. A snap-packaged Chromium (local dev) can only
  # write inside the snap area, so give it a profile dir there and skip the sandbox.
  SNAP_CHROMIUM = "/snap/bin/chromium".freeze

  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ] do |options|
    if File.exist?(SNAP_CHROMIUM) && !system("which google-chrome > /dev/null 2>&1")
      # One profile per test process: Rails runs the system tests in parallel.
      profile_dir = File.expand_path("~/snap/chromium/common/selenium-profile-#{Process.pid}")
      FileUtils.mkdir_p(profile_dir)
      options.binary = SNAP_CHROMIUM
      options.add_argument("--no-sandbox")
      options.add_argument("--disable-dev-shm-usage")
      options.add_argument("--user-data-dir=#{profile_dir}")
    end
  end

  # The login page submits through its script; under load the click can land
  # before that binds, so wait for it and try once more if still on /login.
  def login_as_admin
    visit login_url
    2.times do
      assert_selector "#login", wait: 5
      page.evaluate_script("typeof App !== 'undefined' && App.Pages && App.Pages.Login ? true : false")
      fill_in "username", with: "administrator"
      fill_in "password", with: "administrator1"
      find("#login").click
      break if has_current_path?(%r{/calendar}, wait: 5)
    end
    assert_current_path %r{/calendar}, wait: 5
  end

  # Confirms the EA message modal (jQuery pages and Turbo confirms alike).
  def confirm_modal(title, button)
    assert_selector "#message-modal .modal-title", text: title, wait: 5
    within("#message-modal") { click_on button }
    assert_no_selector "#message-modal", wait: 5
  end
end
