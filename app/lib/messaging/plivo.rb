# Plivo SMS (https://console.plivo.com/). Message API with auth ID + auth token
# basic auth.
module Messaging
  module Plivo
    module_function

    def key = "plivo"

    def label = "Plivo"

    def supports_long_text? = false

    def enabled?
      Setting.get("messages_plivo_enabled") == "1" &&
        auth_id.present? && auth_token.present? && from_number.present?
    end

    def incoming?
      Setting.get("messages_plivo_incoming") == "1"
    end

    def auth_id(config = Messaging.config) = config["messages_plivo_auth_id"]

    def auth_token(config = Messaging.config) = config["messages_plivo_auth_token"]

    def from_number(config = Messaging.config) = config["messages_plivo_from"]

    def address_for(user)
      Messaging::Template.sms_address(user)
    end

    def deliver(message, config = Messaging.config)
      uri = URI("https://api.plivo.com/v1/Account/#{auth_id(config)}/Message/")
      request = Net::HTTP::Post.new(uri.request_uri, "Content-Type" => "application/json")
      request.basic_auth(auth_id(config), auth_token(config))
      request.body = JSON.generate(src: from_number(config), dst: message.to_address, text: message.body)
      post!(uri, request)
    end

    # [ok, error]: the account resource answers 200 to valid credentials.
    def check_credentials(config = Messaging.config)
      uri = URI("https://api.plivo.com/v1/Account/#{auth_id(config)}/")
      request = Net::HTTP::Get.new(uri.request_uri)
      request.basic_auth(auth_id(config), auth_token(config))
      post!(uri, request)
      [ true, nil ]
    rescue StandardError => e
      [ false, e.message ]
    end

    def post!(uri, request)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = 5
      http.read_timeout = 15
      response = http.request(request)
      return if response.is_a?(Net::HTTPSuccess)

      raise "Plivo #{response.code}: #{response.body.to_s.truncate(200)}"
    end
  end
end
