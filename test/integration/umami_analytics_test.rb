require "test_helper"

class UmamiAnalyticsTest < ActionDispatch::IntegrationTest
  def login_admin
    post "/login/validate", params: { username: "administrator", password: "administrator1" }
    assert_equal({ "success" => true }, response.parsed_body)
  end

  def configure_umami(recorder: "0")
    Setting.set("umami_analytics_url", "https://stats.example.org")
    Setting.set("umami_analytics_website_id", "abc-123")
    Setting.set("umami_analytics_recorder", recorder)
  end

  test "booking page carries no umami scripts when unconfigured" do
    get "/"
    assert_select "script[src*='script.js'][data-website-id]", count: 0
  end

  test "booking page loads the umami script and the recorder when enabled" do
    configure_umami
    get "/"
    assert_select "script[defer][src='https://stats.example.org/script.js'][data-website-id='abc-123']"
    assert_select "script[src='https://stats.example.org/recorder.js']", count: 0

    configure_umami(recorder: "1")
    get "/"
    assert_select "script[defer][src='https://stats.example.org/recorder.js'][data-website-id='abc-123']"
  end

  test "a trailing slash on the url does not double up" do
    Setting.set("umami_analytics_url", "https://stats.example.org/")
    Setting.set("umami_analytics_website_id", "abc-123")
    get "/"
    assert_select "script[src='https://stats.example.org/script.js']"
  end

  test "settings page renders and save strips whitespace" do
    login_admin
    get "/umami_analytics_settings"
    assert_response :success
    assert_select "#umami-analytics-website-id"
    assert_select "#umami-analytics-recorder"

    post "/umami_analytics_settings/save", params: {
      umami_analytics_settings: [
        { name: "umami_analytics_url", value: " https://stats.example.org " },
        { name: "umami_analytics_website_id", value: " abc-123 " },
        { name: "umami_analytics_recorder", value: "1" }
      ]
    }
    assert_response :success
    assert_equal "https://stats.example.org", Setting.get("umami_analytics_url")
    assert_equal "abc-123", Setting.get("umami_analytics_website_id")
    assert_equal "1", Setting.get("umami_analytics_recorder")
  end

  test "integrations page shows the umami card before google analytics" do
    login_admin
    get "/integrations"
    body = response.body
    assert_operator body.index(I18n.t("ea.umami_analytics")), :<, body.index(I18n.t("ea.google_analytics"))
    assert_select "a[href='/umami_analytics_settings']"
  end

  test "the umami strings exist in every locale" do
    I18n.available_locales.each do |locale|
      %w[umami_analytics umami_analytics_info umami_analytics_url umami_analytics_url_hint
         umami_analytics_website_id umami_analytics_recorder umami_analytics_recorder_hint].each do |key|
        assert I18n.t("ea.#{key}", locale: locale, fallback: false, default: nil).present?,
               "missing ea.#{key} in #{locale}"
      end
    end
  end
end
