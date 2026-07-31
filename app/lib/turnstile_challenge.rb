# Cloudflare Turnstile captcha (alternative provider to ALTCHA).
module TurnstileChallenge
  VERIFY_URL = URI("https://challenges.cloudflare.com/turnstile/v0/siteverify")

  module_function

  def configured?
    site_key.present? && secret_key.present?
  end

  # Active on the customer booking flow.
  def enabled?
    Captcha.for_customers == "turnstile"
  end

  def site_key = Setting.get("turnstile_site_key").to_s

  def secret_key = Setting.get("turnstile_secret_key").to_s

  # Server-side verification of the widget token via Cloudflare's siteverify.
  # secret can be overridden to verify against not-yet-saved settings.
  def verify(token, remote_ip, secret: secret_key)
    verify_detailed(token, remote_ip, secret: secret)[:success]
  end

  # Like verify but returns { success:, errors: } with Cloudflare's error codes
  # so the settings page can say why activation failed.
  def verify_detailed(token, remote_ip, secret: secret_key)
    return { success: false, errors: [ "missing-input-response" ] } if token.blank?

    remote_ip = usable_remote_ip(remote_ip)

    http = Net::HTTP.new(VERIFY_URL.host, VERIFY_URL.port)
    http.use_ssl = true
    http.open_timeout = 5
    http.read_timeout = 10

    request = Net::HTTP::Post.new(VERIFY_URL.request_uri)
    request.set_form_data({ "secret" => secret, "response" => token, "remoteip" => remote_ip }.compact)

    body = JSON.parse(http.request(request).body)
    success = body["success"] == true
    Rails.logger.warn("Turnstile verification rejected: #{body['error-codes']}") unless success
    { success: success, errors: Array(body["error-codes"]) }
  rescue StandardError => e
    Rails.logger.warn("Turnstile verification failed: #{e.message}")
    { success: false, errors: [ "request-failed" ] }
  end

  # Cloudflare fails verification when remoteip does not match the IP it saw
  # the visitor from. Without a proxy (local sites) the request IP is loopback
  # or private and never matches, so only forward publicly routable addresses.
  def usable_remote_ip(remote_ip)
    return nil if remote_ip.blank?

    addr = IPAddr.new(remote_ip.to_s)
    addr.loopback? || addr.private? || addr.link_local? ? nil : remote_ip
  rescue IPAddr::InvalidAddressError
    nil
  end
end
