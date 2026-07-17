require "test_helper"

class IframeEmbedTest < ActionDispatch::IntegrationTest
  ORIGIN = "https://openouthair.com".freeze

  def enable_embedding
    Setting.set("allow_iframe_embedding", "1")
    Setting.set("iframe_embed_origin", ORIGIN)
  end

  def login_admin
    post "/login/validate", params: { username: "administrator", password: "administrator1" }
  end

  test "disabled by default: SAMEORIGIN everywhere, no frame-ancestors" do
    get "/"
    assert_equal "SAMEORIGIN", response.headers["X-Frame-Options"]
    assert_nil response.headers["Content-Security-Policy"]
  end

  test "enabled: booking flow allows the configured origin, backend stays SAMEORIGIN" do
    enable_embedding
    get "/"
    assert_nil response.headers["X-Frame-Options"]
    assert_equal "frame-ancestors 'self' #{ORIGIN}", response.headers["Content-Security-Policy"]

    get "/login"
    assert_equal "SAMEORIGIN", response.headers["X-Frame-Options"]
  end

  test "a malformed origin is ignored in the header" do
    Setting.set("allow_iframe_embedding", "1")
    Setting.set("iframe_embed_origin", "javascript:alert(1) https://x.com")
    get "/"
    assert_equal "frame-ancestors 'self'", response.headers["Content-Security-Policy"]
  end

  test "booking layout carries the resize snippet only when enabled" do
    get "/"
    assert_no_match(/openappointments:height/, response.body)

    enable_embedding
    get "/"
    assert_match(/openappointments:height/, response.body)
  end

  test "cookie same-site policy relaxes only for the embedded booking flow" do
    assert_equal :lax, Embedding.same_site_for("/", enabled: false)
    assert_equal :none, Embedding.same_site_for("/", enabled: true)
    assert_equal :none, Embedding.same_site_for("/booking/register", enabled: true)
    assert_equal :lax, Embedding.same_site_for("/calendar", enabled: true)
    assert_equal :lax, Embedding.same_site_for("/login", enabled: true)
  end

  test "embed settings page renders the snippet and saves" do
    enable_embedding
    login_admin
    get "/embed_settings"
    assert_response :success
    assert_match "iframe", response.body
    assert_match ORIGIN, response.body
    assert_match(/openappointments:height/, response.body)

    post "/embed_settings/save", params: {
      embed_settings: [
        { name: "allow_iframe_embedding", value: "1" },
        { name: "iframe_embed_origin", value: "https://example.org" }
      ]
    }
    assert_response :success
    assert_equal "https://example.org", Setting.get("iframe_embed_origin")
  end

  test "embed settings need the system settings privilege" do
    post "/login/validate", params: { username: "janedoe", password: "janedoe1" }
    get "/embed_settings"
    assert_response :forbidden
  end

  test "the embed strings exist in every locale" do
    I18n.available_locales.each do |locale|
      %w[embedding allow_iframe_embedding iframe_embed_origin embed_code embed_hint].each do |key|
        assert I18n.t("ea.#{key}", locale: locale, fallback: false, default: nil).present?,
               "missing ea.#{key} in #{locale}"
      end
    end
  end
end
