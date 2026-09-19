require "test_helper"

# The admin layout links only the vendor assets the pages use.
class BackendAssetsTest < ActionDispatch::IntegrationTest
  test "admin pages do not load select2" do
    post "/login/validate", params: { username: "administrator", password: "administrator1" }
    get "/calendar"
    assert_response :success
    assert_no_match(/select2/i, response.body)
  end
end
