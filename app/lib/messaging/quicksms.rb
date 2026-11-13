# QuickSMS (https://www.quicksms.com/). Messaging API with a Bearer API key
# (sk_live_ or sk_test_, a test key never delivers); inbound V2 webhooks are
# signed with the inbound number's secret over "timestamp.body".
module Messaging
  module Quicksms
    module_function

    def key = "quicksms"

    def label = "QuickSMS"

    # Up to 1,530 characters per message, billed per SMS part.
    def supports_long_text? = true

    def enabled?
      Setting.get("messages_quicksms_enabled") == "1" && api_key.present?
    end

    def incoming?
      Setting.get("messages_quicksms_incoming") == "1"
    end

    def api_key(config = Messaging.config) = config["messages_quicksms_api_key"]

    def sender(config = Messaging.config) = config["messages_quicksms_from"]

    def signing_secret = Setting.get("messages_quicksms_signing_secret").to_s

    def address_for(user)
      Messaging::Template.sms_address(user)
    end

    # A 202 means accepted, not delivered, and a recipient can still be
    # rejected inside it, so the response body is checked as well.
    def deliver(message, config = Messaging.config)
      uri = URI("https://api.quicksms.com/v1/messages")
      request = Net::HTTP::Post.new(uri.request_uri, headers(config))
      request.body = JSON.generate(mobile_number: message.to_address.to_s.delete("+"), msg: message.body, sender: sender(config))
      body = post!(uri, request)
      rejected = JSON.parse(body).fetch("messages", []).find { |row| row["status"] == "REJECTED" }
      return unless rejected

      error = rejected["error"] || {}
      raise "QuickSMS #{error['code']}: #{error['message']}"
    end

    # [ok, error]: reading a message id that cannot exist answers 404 to a
    # valid key and 401 to a bad one, without sending anything.
    def check_credentials(config = Messaging.config)
      uri = URI("https://api.quicksms.com/v2/messages/credential-check")
      response = http_for(uri).request(Net::HTTP::Get.new(uri.request_uri, headers(config)))
      return [ true, nil ] if response.is_a?(Net::HTTPNotFound) || response.is_a?(Net::HTTPSuccess)

      [ false, "QuickSMS #{response.code}: #{response.body.to_s.truncate(200)}" ]
    rescue StandardError => e
      [ false, e.message ]
    end

    # "sha256=<hex>" HMAC-SHA256 over "timestamp.body" with the signing secret;
    # a timestamp more than five minutes off is stale.
    def valid_signature?(signature, timestamp, raw_body, now = Time.now)
      return false if signing_secret.blank? || signature.blank? || timestamp.blank?
      return false if (now.to_i - timestamp.to_i).abs > 300

      digest = OpenSSL::HMAC.hexdigest("sha256", signing_secret, "#{timestamp}.#{raw_body}")
      ActiveSupport::SecurityUtils.secure_compare("sha256=#{digest}", signature.to_s.downcase)
    end

    def headers(config)
      { "Content-Type" => "application/json", "Authorization" => "Bearer #{api_key(config)}" }
    end

    def http_for(uri)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = 5
      http.read_timeout = 15
      http
    end

    def post!(uri, request)
      response = http_for(uri).request(request)
      return response.body.to_s if response.is_a?(Net::HTTPSuccess)

      raise "QuickSMS #{response.code}: #{response.body.to_s.truncate(200)}"
    end
  end
end
