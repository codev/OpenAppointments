require "test_helper"

class AltchaTest < ActionDispatch::IntegrationTest
  def enable_altcha
    Setting.set("require_captcha", "1")
    Setting.set("altcha_enabled", "1")
    Setting.set("captcha_provider", "altcha")
    Setting.set("altcha_hmac_key", "test-hmac-key")
    Setting.set("altcha_max_number", "100")
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

  test "verify accepts a solved challenge payload and rejects garbage" do
    enable_altcha
    challenge = AltchaChallenge.create_challenge
    solution = Altcha::V1.solve_challenge(challenge.challenge, challenge.salt,
                                          challenge.algorithm, challenge.maxnumber, 0)
    payload = Base64.strict_encode64({
      algorithm: challenge.algorithm, challenge: challenge.challenge,
      number: solution.number, salt: challenge.salt, signature: challenge.signature
    }.to_json)

    assert AltchaChallenge.verify(payload)
    assert_not AltchaChallenge.verify("not-a-payload")
    assert_not AltchaChallenge.verify("")
    assert_not AltchaChallenge.verify(nil)
  end
end
