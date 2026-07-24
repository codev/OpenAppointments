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

    def api_key = Setting.get("messages_textanywhere_api_key").to_s

    def from_name = Setting.get("messages_textanywhere_from").to_s

    def address_for(user)
      Messaging::Template.sms_address(user)
    end

    def deliver(message)
      uri = URI("https://api.textanywhere.com/API/v1.0/REST/sms")
      request = Net::HTTP::Post.new(uri.request_uri,
                                    "Content-Type" => "application/json",
                                    "Authorization" => "Bearer #{api_key}")
      body = { message_type: "SI", message: message.body, recipient: [ message.to_address ] }
      body[:sender] = from_name if from_name.present?
      request.body = JSON.generate(body)
      post!(uri, request)
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
