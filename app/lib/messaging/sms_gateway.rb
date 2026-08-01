# SMS Gateway for Android private server (sms-gate.app). The Android app in
# Private Server mode registers against the self-hosted server; sending goes
# through the server's third party API (basic auth credentials generated at
# device registration), incoming SMS arrive as HMAC-signed webhooks posted by
# the device itself.
module Messaging
  module SmsGateway
    module_function

    def key = "smsgateway"

    def label = "SMS Gateway"

    # The Android app auto-partitions long messages.
    def supports_long_text? = true

    def enabled?
      Setting.get("messages_smsgateway_enabled") == "1" &&
        base_url.present? && login.present? && password.present?
    end

    def incoming?
      Setting.get("messages_smsgateway_incoming") == "1"
    end

    def base_url = Setting.get("messages_smsgateway_url").to_s.strip.chomp("/")

    def login = Setting.get("messages_smsgateway_login").to_s

    def password = Setting.get("messages_smsgateway_password").to_s

    def signing_key = Setting.get("messages_smsgateway_signing_key").to_s

    def address_for(user)
      Messaging::Template.sms_address(user)
    end

    def deliver(message)
      request = Net::HTTP::Post.new(api_uri("message").request_uri, "Content-Type" => "application/json")
      request.basic_auth(login, password)
      request.body = { message: message.body, phoneNumbers: [ message.to_address ] }.to_json
      post!(api_uri("message"), request)
    end

    # Credential check against the server: nil when good, an error string otherwise.
    def validate(url: base_url, user: login, pass: password)
      uri = URI("#{url.to_s.strip.chomp('/')}/api/3rdparty/v1/device")
      request = Net::HTTP::Get.new(uri.request_uri)
      request.basic_auth(user, pass)
      response = http_for(uri).request(request)
      case response
      when Net::HTTPSuccess then nil
      when Net::HTTPUnauthorized then "wrong API login or password"
      else "server answered #{response.code}"
      end
    rescue StandardError => e
      e.message
    end

    # Ensures exactly one sms:received webhook for our inbound path: stale and
    # duplicate registrations are removed, the URL is registered if missing.
    def ensure_webhook(url)
      ours = webhooks.select { |hook| hook["url"].to_s.include?("/messages/inbound/smsgateway/") }
      keep = ours.find { |hook| hook["url"] == url }
      ours.each { |hook| delete_webhook(hook["id"]) unless hook.equal?(keep) }
      register_webhook(url) unless keep
    end

    # Removes every registration pointing at our inbound path.
    def remove_webhooks
      webhooks.each do |hook|
        delete_webhook(hook["id"]) if hook["url"].to_s.include?("/messages/inbound/smsgateway/")
      end
    end

    def webhooks
      request = Net::HTTP::Get.new(api_uri("webhooks").request_uri)
      request.basic_auth(login, password)
      response = http_for(api_uri("webhooks")).request(request)
      raise "SMS Gateway #{response.code}: #{response.body.to_s.truncate(200)}" unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body)
    end

    def delete_webhook(id)
      uri = api_uri("webhooks/#{id}")
      request = Net::HTTP::Delete.new(uri.request_uri)
      request.basic_auth(login, password)
      http_for(uri).request(request)
    end

    # Registers the incoming-SMS webhook on the server; the device fetches the
    # registration and posts matching events straight to the URL.
    def register_webhook(url)
      request = Net::HTTP::Post.new(api_uri("webhooks").request_uri, "Content-Type" => "application/json")
      request.basic_auth(login, password)
      request.body = { url: url, event: "sms:received" }.to_json
      post!(api_uri("webhooks"), request)
    end

    # Device webhooks sign hex HMAC-SHA256 over raw body + timestamp with the
    # signing key from the app's Settings > Webhooks.
    def valid_signature?(signature, timestamp, raw_body)
      return false if signing_key.blank? || signature.blank? || timestamp.blank?

      digest = OpenSSL::HMAC.hexdigest("sha256", signing_key, raw_body.to_s + timestamp.to_s)
      ActiveSupport::SecurityUtils.secure_compare(digest, signature.to_s.downcase)
    end

    def api_uri(path)
      URI("#{base_url}/api/3rdparty/v1/#{path}")
    end

    def http_for(uri)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = 5
      http.read_timeout = 15
      http
    end

    def post!(uri, request)
      response = http_for(uri).request(request)
      return if response.is_a?(Net::HTTPSuccess)

      raise "SMS Gateway #{response.code}: #{response.body.to_s.truncate(200)}"
    end
  end
end
