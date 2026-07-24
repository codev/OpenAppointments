require "test_helper"
require "webmock/minitest"

class TurnstileTest < ActionDispatch::IntegrationTest
  VERIFY_URL = "https://challenges.cloudflare.com/turnstile/v0/siteverify".freeze

  def enable_turnstile
    Setting.set("require_captcha", "1")
    Setting.set("captcha_provider", "turnstile")
    Setting.set("turnstile_site_key", "sitekey")
    Setting.set("turnstile_secret_key", "secretkey")
  end

  def register(token: nil)
    params = {
      post_data: {
        appointment: {
          "start_datetime" => "2026-07-20 11:00:00",
          "id_services" => services(:haircut).id, "id_users_provider" => users(:zane).id
        },
        customer: { "name" => "Captcha Booker", "email" => "captcha@example.org" },
        manage_mode: false
      }
    }
    params[:cf_turnstile_response] = token if token
    travel_to Time.new(2026, 7, 10, 12, 0, 0) do
      post "/booking/register", params: params
    end
  end

  test "enabled only with captcha on, provider turnstile and both keys" do
    assert_not TurnstileChallenge.enabled?
    enable_turnstile
    assert TurnstileChallenge.enabled?
    Setting.set("turnstile_secret_key", "")
    assert_not TurnstileChallenge.enabled?
  end

  test "altcha keeps working when it is the provider" do
    Setting.set("require_captcha", "1")
    Setting.set("altcha_enabled", "1")
    Setting.set("altcha_hmac_key", "k")
    assert AltchaChallenge.enabled?
    assert_not TurnstileChallenge.enabled?

    Setting.set("captcha_provider", "turnstile")
    assert_not AltchaChallenge.enabled?
  end

  test "verify posts to siteverify and honours the answer" do
    enable_turnstile
    stub_request(:post, VERIFY_URL).to_return(body: { success: true }.to_json)
    assert TurnstileChallenge.verify("tok", "1.2.3.4")
    assert_requested(:post, VERIFY_URL) { |req| req.body.include?("secretkey") && req.body.include?("tok") }

    stub_request(:post, VERIFY_URL).to_return(body: { success: false }.to_json)
    assert_not TurnstileChallenge.verify("bad", nil)

    stub_request(:post, VERIFY_URL).to_timeout
    assert_not TurnstileChallenge.verify("tok", nil)

    assert_not TurnstileChallenge.verify("", nil)
  end

  test "booking page renders the widget and script only when enabled" do
    get "/"
    assert_no_match(/cf-turnstile/, response.body)
    assert_no_match(/challenges\.cloudflare\.com/, response.body)

    enable_turnstile
    get "/"
    assert_select ".cf-turnstile[data-sitekey=?]", "sitekey"
    assert_match(/challenges\.cloudflare\.com\/turnstile/, response.body)
  end

  test "register rejects a failed verification with the EA-style flag" do
    enable_turnstile
    stub_request(:post, VERIFY_URL).to_return(body: { success: false }.to_json)
    assert_no_difference "Appointment.count" do
      register(token: "bad")
    end
    assert_equal false, response.parsed_body["turnstile_verification"]
  end

  test "register books with a valid token" do
    enable_turnstile
    stub_request(:post, VERIFY_URL).to_return(body: { success: true }.to_json)
    assert_difference "Appointment.count", 1 do
      register(token: "good")
    end
    assert_response :success
    assert response.parsed_body["appointment_hash"].present?
  end

  test "settings save stores the provider and keys" do
    post "/login/validate", params: { username: "administrator", password: "administrator1" }
    post "/altcha_settings/save", params: {
      altcha_settings: [
        { name: "captcha_provider", value: "turnstile" },
        { name: "turnstile_site_key", value: "sk" },
        { name: "turnstile_secret_key", value: "sec" }
      ]
    }
    assert_response :success
    assert_equal "turnstile", Setting.get("captcha_provider")
    assert_equal "sec", Setting.get("turnstile_secret_key")
  end

  test "the new strings exist in every locale" do
    I18n.available_locales.each do |locale|
      %w[captcha_provider turnstile_site_key turnstile_secret_key turnstile_verification_failed].each do |key|
        assert I18n.t("ea.#{key}", locale: locale, fallback: false, default: nil).present?,
               "missing ea.#{key} in #{locale}"
      end
    end
  end
end
