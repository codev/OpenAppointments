# Picks the active captcha provider per surface. A provider only counts when it
# is fully configured. The altcha_enabled setting is the provider-agnostic
# "Active for customers" switch on the captcha settings page (legacy name kept
# for existing installs); captcha_login_enabled gates the backend login.
module Captcha
  module_function

  # "altcha", "turnstile" or nil when unconfigured.
  def provider
    name = Setting.get("captcha_provider", "altcha")
    challenge = name == "turnstile" ? TurnstileChallenge : AltchaChallenge
    challenge.configured? ? name : nil
  end

  def for_customers
    Setting.get("altcha_enabled") == "1" ? provider : nil
  end

  def for_login
    Setting.get("captcha_login_enabled", "0") == "1" ? provider : nil
  end
end
