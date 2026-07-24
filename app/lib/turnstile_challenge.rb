# Cloudflare Turnstile captcha (alternative provider to ALTCHA).
module TurnstileChallenge
  VERIFY_URL = URI("https://challenges.cloudflare.com/turnstile/v0/siteverify")

  module_function

  # The altcha_enabled setting is the provider-agnostic "Active" switch on the
  # captcha settings page (legacy name kept for existing installs).
  def enabled?
    Setting.get("require_captcha") == "1" &&
      Setting.get("altcha_enabled") == "1" &&
      Setting.get("captcha_provider", "altcha") == "turnstile" &&
      site_key.present? && secret_key.present?
  end

  def site_key = Setting.get("turnstile_site_key").to_s

  def secret_key = Setting.get("turnstile_secret_key").to_s

  # Server-side verification of the widget token via Cloudflare's siteverify.
  def verify(token, remote_ip)
    return false if token.blank?

    http = Net::HTTP.new(VERIFY_URL.host, VERIFY_URL.port)
    http.use_ssl = true
    http.open_timeout = 5
    http.read_timeout = 10

    request = Net::HTTP::Post.new(VERIFY_URL.request_uri)
    request.set_form_data({ "secret" => secret_key, "response" => token, "remoteip" => remote_ip }.compact)

    response = http.request(request)
    JSON.parse(response.body)["success"] == true
  rescue StandardError => e
    Rails.logger.warn("Turnstile verification failed: #{e.message}")
    false
  end
end
