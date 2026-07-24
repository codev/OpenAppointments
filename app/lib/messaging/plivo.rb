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

    def auth_id = Setting.get("messages_plivo_auth_id").to_s

    def auth_token = Setting.get("messages_plivo_auth_token").to_s

    def from_number = Setting.get("messages_plivo_from").to_s

    def address_for(user)
      Messaging::Template.sms_address(user)
    end

    def deliver(message)
      uri = URI("https://api.plivo.com/v1/Account/#{auth_id}/Message/")
      request = Net::HTTP::Post.new(uri.request_uri, "Content-Type" => "application/json")
      request.basic_auth(auth_id, auth_token)
      request.body = JSON.generate(src: from_number, dst: message.to_address, text: message.body)
      post!(uri, request)
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
