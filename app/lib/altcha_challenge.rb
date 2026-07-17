# ALTCHA proof-of-work captcha (EA Altcha_client, altcha gem).
module AltchaChallenge
  module_function

  def enabled?
    Setting.get("require_captcha") == "1" && Setting.get("altcha_enabled") == "1"
  end

  def hmac_key
    key = Setting.get("altcha_hmac_key").to_s
    key.presence || raise(RuntimeError, "ALTCHA HMAC key is not configured")
  end

  def create_challenge
    options = Altcha::ChallengeOptions.new
    options.hmac_key = hmac_key
    options.max_number = Setting.get("altcha_max_number", "100000").to_i
    options.expires = Time.now + Setting.get("altcha_expires", "300").to_i
    Altcha.create_challenge(options)
  end

  def verify(payload)
    return false if payload.blank?

    Altcha.verify_solution(payload, hmac_key, true)
  rescue StandardError
    false
  end
end
