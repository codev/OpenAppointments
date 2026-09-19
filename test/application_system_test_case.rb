# Browser tests run one at a time: a Chrome per core starves the box and flakes.
# Set before test_helper configures parallelisation.
ENV["PARALLEL_WORKERS"] ||= "1"
require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  # Plain Chrome (CI) works as-is. A snap-packaged Chromium (local dev) can only
  # write inside the snap area, so give it a profile dir there and skip the sandbox.
  SNAP_CHROMIUM = "/snap/bin/chromium".freeze

  SCREEN_SIZE = [ 1400, 1400 ].freeze

  driven_by :selenium, using: :headless_chrome, screen_size: SCREEN_SIZE do |options|
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

  # The booking wizard labels hours in the browser's zone, so the browser is
  # pinned to the fixture provider's zone whatever the runner's clock says.
  BROWSER_TIMEZONE = "Europe/London".freeze

  setup do
    page.driver.browser.execute_cdp("Emulation.setTimezoneOverride", timezoneId: BROWSER_TIMEZONE)
  end

  # One browser serves the whole run, so a test that changes the window size
  # must hand the next test the configured size back.
  def resize_window(width, height)
    @window_resized = true
    page.driver.browser.manage.window.resize_to(width, height)
  end

  teardown do
    page.driver.browser.manage.window.resize_to(*SCREEN_SIZE) if @window_resized
  end

  def login_as_admin
    visit login_url
    assert_selector "#login", wait: 15 # the first page of a run waits for Puma
    fill_in "username", with: "administrator"
    fill_in "password", with: "administrator1"
    find("#login").click
    assert_current_path %r{/calendar}, wait: 10
  end

  # Typing during Bootstrap's fade-in loses keys to its focus handling, and a
  # dismiss click during the transition is ignored: wait for the shown modal to
  # be opaque and for Bootstrap to have finished its transition.
  def wait_for_modal
    assert_selector ".modal.show", wait: 5
    assert page.has_css?(".modal.show", wait: 5) && wait_until_shown, "modal did not finish showing"
  end

  def wait_until_shown
    50.times do
      shown = page.evaluate_script(<<~JS)
        (() => {
          const element = document.querySelector('.modal.show');
          const instance = element && bootstrap.Modal.getInstance(element);
          return !!element && getComputedStyle(element).opacity === '1' && !!instance && !instance._isTransitioning;
        })()
      JS
      return true if shown
      sleep 0.1
    end
    false
  end

  # Confirms the EA message modal (jQuery pages and Turbo confirms alike).
  def confirm_modal(title, button)
    assert_selector "#message-modal .modal-title", text: title, wait: 5
    within("#message-modal") { click_on button }
    assert_no_selector "#message-modal", wait: 5
  end
end
