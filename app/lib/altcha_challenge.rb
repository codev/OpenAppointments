# ALTCHA proof-of-work captcha (EA Altcha_client, altcha gem).
module AltchaChallenge
  module_function

  def configured?
    Setting.get("altcha_hmac_key").to_s.present?
  end

  # Active on the customer booking flow.
  def enabled?
    Captcha.for_customers == "altcha"
  end

  def hmac_key
    key = Setting.get("altcha_hmac_key").to_s
    key.presence || raise(RuntimeError, "ALTCHA HMAC key is not configured")
  end

  def create_challenge
    options = Altcha::V1::ChallengeOptions.new(
      hmac_key: hmac_key,
      max_number: Setting.get("altcha_max_number", "100000").to_i,
      expires: Time.now + Setting.get("altcha_expires", "300").to_i
    )
    Altcha::V1.create_challenge(options)
  end

  def verify(payload)
    return false if payload.blank?

    Altcha::V1.verify_solution(payload, hmac_key, true)
  rescue StandardError
    false
  end
end
