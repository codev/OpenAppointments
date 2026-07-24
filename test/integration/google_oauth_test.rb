require "test_helper"

class GoogleOauthTest < ActionDispatch::IntegrationTest
  def login_admin
    post "/login/validate", params: { username: "administrator", password: "administrator1" }
  end

  setup do
    Setting.set("google_client_id", "cid")
    Setting.set("google_client_secret", "secret")
    login_admin
  end

  test "oauth redirects to Google with a stored state" do
    get "/google/oauth/#{users(:zane).id}"
    assert_response :redirect
    assert_match "accounts.google.com", response.location
    assert session[:oauth_state].present?
    assert_equal users(:zane).id, session[:oauth_provider_id]
  end

  test "callback rejects a mismatched state" do
    get "/google/oauth/#{users(:zane).id}"
    get "/google/oauth_callback", params: { state: "wrong", code: "abc" }
    assert_response :forbidden
  end

  test "disable_provider_sync clears settings and event ids" do
    zane = users(:zane)
    zane.settings.update!(google_sync: true, google_token: '{"refresh_token":"x"}')
    appointments(:upcoming).update_column(:id_google_calendar, "g1")

    post "/google/disable_provider_sync", params: { provider_id: zane.id }
    assert_equal({ "success" => true }, response.parsed_body)
    assert_not zane.settings.reload.google_sync
    assert_nil zane.settings.google_token
    assert_nil appointments(:upcoming).reload.id_google_calendar
  end

  test "requires a session" do
    reset_session_and_logout
    get "/google/oauth/#{users(:zane).id}"
    assert_redirected_to "/login"
  end

  private

  def reset_session_and_logout
    get "/logout"
  end
end
