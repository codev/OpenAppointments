# TextAnywhere SMS (https://www.textanywhere.com/). REST SMS API with a bearer
# API key.
module Messaging
  module Textanywhere
    module_function

    def key = "textanywhere"

    def label = "TextAnywhere"

    def supports_long_text? = false

    def enabled?
      Setting.get("messages_textanywhere_enabled") == "1" && api_key.present?
    end

    def incoming?
      Setting.get("messages_textanywhere_incoming") == "1"
    end

    def api_key(config = Messaging.config) = config["messages_textanywhere_api_key"]

    def from_name(config = Messaging.config) = config["messages_textanywhere_from"]

    def address_for(user)
      Messaging::Template.sms_address(user)
    end

    def deliver(message, config = Messaging.config)
      uri = URI("https://api.textanywhere.com/API/v1.0/REST/sms")
      request = Net::HTTP::Post.new(uri.request_uri, headers(config))
      body = { message_type: "SI", message: message.body, recipient: [ message.to_address ] }
      body[:sender] = from_name(config) if from_name(config).present?
      request.body = JSON.generate(body)
      post!(uri, request)
    end

    # [ok, error]: the account status resource answers 200 to a valid key.
    def check_credentials(config = Messaging.config)
      uri = URI("https://api.textanywhere.com/API/v1.0/REST/status")
      post!(uri, Net::HTTP::Get.new(uri.request_uri, headers(config)))
      [ true, nil ]
    rescue StandardError => e
      [ false, e.message ]
    end

    def headers(config)
      { "Content-Type" => "application/json", "Authorization" => "Bearer #{api_key(config)}" }
    end

    def post!(uri, request)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = 5
      http.read_timeout = 15
      response = http.request(request)
      return if response.is_a?(Net::HTTPSuccess)

      raise "TextAnywhere #{response.code}: #{response.body.to_s.truncate(200)}"
    end
  end
end
