require "test_helper"

# The admin layout links only the vendor assets the pages use.
class BackendAssetsTest < ActionDispatch::IntegrationTest
  test "admin pages do not load select2" do
    post "/login/validate", params: { username: "administrator", password: "administrator1" }
    get "/calendar"
    assert_response :success
    assert_no_match(/select2/i, response.body)
  end

  # The calendar's unavailability, break and custom textures are pictures under
  # app/assets/images; the built stylesheet must point at their digested paths.
  test "the backend stylesheet links the calendar textures through the asset pipeline" do
    post "/login/validate", params: { username: "administrator", password: "administrator1" }
    get "/calendar"
    href = response.body[%r{href="(/assets/backend-[^"]+\.css)"}, 1]
    refute_nil href, "backend stylesheet link"
    get href
    assert_response :success
    %w[unavailability break custom].each do |texture|
      assert_match "/assets/#{texture}-", response.body, "#{texture}.jpg resolved by Propshaft"
    end
    assert_no_match "/img/", response.body
  end
end
