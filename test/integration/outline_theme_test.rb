require "test_helper"

class OutlineThemeTest < ActionDispatch::IntegrationTest
  test "outline is a whitelisted theme" do
    assert_includes BookingController::THEMES, "outline"
  end

  test "the booking page accepts theme=outline" do
    get "/", params: { theme: "outline" }
    assert_response :success
    assert_match %r{themes/outline}, response.body
  end

  test "the dartsass build includes the outline theme" do
    builds = Rails.application.config.dartsass.builds
    assert_equal "themes/outline.css", builds["ea/themes/outline.scss"]
  end

  test "the theme source uses outline styling" do
    source = Rails.root.join("app/assets/stylesheets/ea/themes/outline.scss").read
    assert_match(/button-outline-variant/, source)
    assert_match(/@import 'bootstrap'/, source)
  end
end
