require "test_helper"

class AltchaTest < ActionDispatch::IntegrationTest
  def enable_altcha
    Setting.set("altcha_enabled", "1")
    Setting.set("captcha_provider", "altcha")
    Setting.set("altcha_hmac_key", "test-hmac-key")
    Setting.set("altcha_max_number", "100")
  end

  def enable_login_captcha
    Setting.set("captcha_login_enabled", "1")
    Setting.set("captcha_provider", "altcha")
    Setting.set("altcha_hmac_key", "test-hmac-key")
    Setting.set("altcha_max_number", "100")
  end

  def solved_payload
    challenge = AltchaChallenge.create_challenge
    solution = Altcha::V1.solve_challenge(challenge.challenge, challenge.salt,
                                          challenge.algorithm, challenge.maxnumber, 0)
    Base64.strict_encode64({
      algorithm: challenge.algorithm, challenge: challenge.challenge,
      number: solution.number, salt: challenge.salt, signature: challenge.signature
    }.to_json)
  end

  test "challenge endpoint returns a solvable challenge" do
    enable_altcha
    get "/captcha/altcha_challenge"
    assert_response :success
    body = response.parsed_body
    assert_equal "SHA-256", body["algorithm"]
    assert_equal 100, body["maxnumber"]
    assert body["challenge"].present?
    assert body["salt"].present?
    assert body["signature"].present?
  end

  test "challenge endpoint reports a missing HMAC key instead of crashing" do
    enable_altcha
    Setting.set("altcha_hmac_key", "")
    get "/captcha/altcha_challenge"
    assert_response :internal_server_error
    assert_equal false, response.parsed_body["success"]
  end

  test "enabled requires the customer switch, the provider and the HMAC key" do
    assert_not AltchaChallenge.enabled?
    enable_altcha
    assert AltchaChallenge.enabled?

    Setting.set("captcha_provider", "turnstile")
    assert_not AltchaChallenge.enabled?

    Setting.set("captcha_provider", "altcha")
    Setting.set("altcha_hmac_key", "")
    assert_not AltchaChallenge.enabled?

    Setting.set("altcha_hmac_key", "test-hmac-key")
    Setting.set("altcha_enabled", "0")
    assert_not AltchaChallenge.enabled?
  end

  test "login page renders the widget only when the login captcha is on" do
    get "/login"
    assert_select "#altcha-widget", count: 0

    enable_altcha
    get "/login"
    assert_select "#altcha-widget", count: 0, message: "customer switch must not affect login"

    enable_login_captcha
    get "/login"
    assert_select "#altcha-widget"

    Setting.set("captcha_provider", "turnstile")
    get "/login"
    assert_select "#altcha-widget", count: 0
  end

  test "recovery pages render the login captcha widget" do
    enable_login_captcha
    get "/recovery"
    assert_select "#altcha-widget"
  end

  test "login is gated by ALTCHA when active for login" do
    enable_login_captcha

    post "/login/validate", params: { username: "administrator", password: "administrator1" }
    assert_equal false, response.parsed_body["altcha_verification"]

    post "/login/validate", params: { username: "administrator", password: "administrator1",
                                      altcha_payload: "garbage" }
    assert_equal false, response.parsed_body["altcha_verification"]

    post "/login/validate", params: { username: "administrator", password: "administrator1",
                                      altcha_payload: solved_payload }
    assert_equal true, response.parsed_body["success"]
  end

  test "login ignores the captcha when only the customer switch is on" do
    enable_altcha
    post "/login/validate", params: { username: "administrator", password: "administrator1" }
    assert_equal true, response.parsed_body["success"]
  end

  test "booking page shows no captcha markup when the provider is unconfigured" do
    Setting.set("altcha_enabled", "1")
    Setting.set("captcha_provider", "turnstile")
    get "/"
    assert_select "#altcha-widget", count: 0
    assert_select ".cf-turnstile", count: 0
  end

  test "verify accepts a solved challenge payload and rejects garbage" do
    enable_altcha
    assert AltchaChallenge.verify(solved_payload)
    assert_not AltchaChallenge.verify("not-a-payload")
    assert_not AltchaChallenge.verify("")
    assert_not AltchaChallenge.verify(nil)
  end

  test "save refuses to activate ALTCHA without an HMAC key" do
    post "/login/validate", params: { username: "administrator", password: "administrator1" }

    post "/altcha_settings/save", params: {
      altcha_settings: [
        { name: "altcha_enabled", value: "1" },
        { name: "captcha_provider", value: "altcha" },
        { name: "altcha_hmac_key", value: "" }
      ]
    }
    assert_equal false, response.parsed_body["success"]
    assert_equal I18n.t("ea.altcha_hmac_key_missing"), response.parsed_body["message"]
    assert_not_equal "1", Setting.get("altcha_enabled")

    post "/altcha_settings/save", params: {
      altcha_settings: [
        { name: "captcha_login_enabled", value: "1" },
        { name: "captcha_provider", value: "altcha" },
        { name: "altcha_hmac_key", value: "" }
      ]
    }
    assert_equal false, response.parsed_body["success"]

    post "/altcha_settings/save", params: {
      altcha_settings: [
        { name: "altcha_enabled", value: "1" },
        { name: "captcha_provider", value: "altcha" },
        { name: "altcha_hmac_key", value: "abc123" }
      ]
    }
    assert_equal true, response.parsed_body["success"]
    assert_equal "1", Setting.get("altcha_enabled")
  end

  test "save refuses to activate Turnstile without both keys" do
    post "/login/validate", params: { username: "administrator", password: "administrator1" }

    post "/altcha_settings/save", params: {
      altcha_settings: [
        { name: "captcha_login_enabled", value: "1" },
        { name: "captcha_provider", value: "turnstile" },
        { name: "turnstile_site_key", value: "sk" },
        { name: "turnstile_secret_key", value: "" }
      ]
    }
    assert_equal false, response.parsed_body["success"]
    assert_equal I18n.t("ea.turnstile_keys_missing"), response.parsed_body["message"]
    assert_not_equal "1", Setting.get("captcha_login_enabled")
  end

  VERIFY_URL = "https://challenges.cloudflare.com/turnstile/v0/siteverify".freeze

  def activate_turnstile_params
    {
      altcha_settings: [
        { name: "captcha_login_enabled", value: "1" },
        { name: "captcha_provider", value: "turnstile" },
        { name: "turnstile_site_key", value: "sk" },
        { name: "turnstile_secret_key", value: "sec" }
      ]
    }
  end

  test "activating Turnstile requires a verified test challenge from this site" do
    require "webmock/minitest"
    post "/login/validate", params: { username: "administrator", password: "administrator1" }

    # No test token at all: the widget could not run here.
    post "/altcha_settings/save", params: activate_turnstile_params
    assert_equal false, response.parsed_body["success"]
    assert_equal I18n.t("ea.turnstile_test_failed"), response.parsed_body["message"]
    assert_not_equal "1", Setting.get("captcha_login_enabled")

    # Token present but Cloudflare rejects it.
    stub_request(:post, VERIFY_URL).to_return(body: { success: false }.to_json)
    post "/altcha_settings/save", params: activate_turnstile_params.merge(cf_turnstile_response: "bad")
    assert_equal false, response.parsed_body["success"]
    assert_not_equal "1", Setting.get("captcha_login_enabled")

    # Verified token: activation goes through, checked with the posted secret.
    stub_request(:post, VERIFY_URL).to_return(body: { success: true }.to_json)
    post "/altcha_settings/save", params: activate_turnstile_params.merge(cf_turnstile_response: "good")
    assert_equal true, response.parsed_body["success"]
    assert_equal "1", Setting.get("captcha_login_enabled")
    assert_requested(:post, VERIFY_URL, times: 2)
    assert_requested(:post, VERIFY_URL) { |req| req.body.include?("secret=sec") && req.body.include?("good") }

    # Already active with the same keys: saving again needs no fresh test.
    WebMock.reset!
    post "/altcha_settings/save", params: activate_turnstile_params
    assert_equal true, response.parsed_body["success"]

    # Changing a key while active requires a fresh verified test.
    changed = activate_turnstile_params
    changed[:altcha_settings][2][:value] = "sk-new"
    post "/altcha_settings/save", params: changed
    assert_equal false, response.parsed_body["success"]
    assert_equal I18n.t("ea.turnstile_test_failed"), response.parsed_body["message"]
    assert_equal "sk", Setting.get("turnstile_site_key")
  end

  test "the new strings exist and the removed keys are gone in every locale" do
    I18n.available_locales.each do |locale|
      %w[captcha_enabled_hint captcha_active_customers captcha_active_login captcha_login_hint
         altcha_hmac_key_missing turnstile_keys_missing
         turnstile_test_hint turnstile_test_failed].each do |key|
        assert I18n.t("ea.#{key}", locale: locale, fallback: false, default: nil).present?,
               "missing ea.#{key} in #{locale}"
      end
      %w[require_captcha_hint captcha_is_wrong altcha_captcha_not_active_warning].each do |key|
        assert_nil I18n.t("ea.#{key}", locale: locale, fallback: false, default: nil),
                   "removed key ea.#{key} still present in #{locale}"
      end
    end
  end
end
